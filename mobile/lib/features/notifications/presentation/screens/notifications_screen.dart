import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final customerId = await CustomerIdentityService(client: _client).getCustomerId();
    final rows = await _client
        .from('notifications')
        .select('''
          id,
          booking_request_id,
          event_key,
          type,
          title,
          body,
          is_read,
          created_at
        ''')
        .eq('user_id', customerId)
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> _refresh() async {
    final future = _loadNotifications();
    setState(() {
      _notificationsFuture = future;
    });
    await future;
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final customerId = await CustomerIdentityService(client: _client).getCustomerId();

    final id = notification['id']?.toString() ?? '';
    if (notification['is_read'] != true && id.isNotEmpty) {
      try {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', id)
            .eq('user_id', customerId);
        notification['is_read'] = true;
        if (mounted) setState(() {});
      } catch (error) {
        debugPrint('Could not mark notification read: $error');
      }
    }

    final type = notification['type']?.toString().trim().toLowerCase() ?? '';
    final requestId = notification['booking_request_id']?.toString().trim() ?? '';
    final eventKey = notification['event_key']?.toString().trim() ?? '';

    if (!mounted) return;

    if ((type == 'trainer_match' || type == 'match_ready') && requestId.isNotEmpty) {
      context.push(GSWRoutes.matchedTrainer, extra: requestId);
      return;
    }

    const sessionTypes = {
      'booking_confirmed',
      'booking_cancelled',
      'booking_rescheduled',
      'session_reminder',
      'session_feedback',
    };

    if (!sessionTypes.contains(type)) return;

    String? sessionId;
    final eventParts = eventKey.split(':');
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // The outbox uses event keys such as:
    // booking_cancelled:<session_id>
    // booking_rescheduled:<session_id>:<reschedule_count>
    if (eventParts.length >= 2 && eventParts.first == type && uuidPattern.hasMatch(eventParts[1])) {
      sessionId = eventParts[1];
    }

    try {
      // The database remains the authority for session ownership.
      if (sessionId != null) {
        final existing = await _client
            .from('sessions')
            .select('id')
            .eq('id', sessionId)
            .eq('user_id', customerId)
            .maybeSingle();
        if (existing == null) sessionId = null;
      }

      // Fallback for older notifications without an outbox event key.
      if (sessionId == null && requestId.isNotEmpty) {
        final session = await _client
            .from('sessions')
            .select('id')
            .eq('booking_request_id', requestId)
            .eq('user_id', customerId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        sessionId = session?['id']?.toString();
      }
    } catch (error) {
      debugPrint('Could not resolve notification session: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open this session right now.')));
      return;
    }

    if (!mounted) return;
    if (sessionId != null && sessionId.isNotEmpty) {
      context.push(
        GSWRoutes.sessionDetails,
        extra: type == 'session_feedback'
            ? {'sessionId': sessionId, 'openFeedback': true}
            : sessionId,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session details are unavailable.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: GSWColors.backgroundPrimary,
      ),
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
              }
              if (snapshot.hasError) {
                return _buildErrorState();
              }
              final notifications = snapshot.data ?? [];
              return RefreshIndicator(
                onRefresh: _refresh,
                color: GSWColors.primary,
                backgroundColor: GSWColors.surfacePrimary,
                child: ScrollConfiguration(
                  behavior: const _NoScrollEffectBehavior(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackButton(),
                        const SizedBox(height: 24),
                        Text(
                          'NOTIFICATIONS',
                          style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
                        ),
                        const SizedBox(height: 24),
                        if (notifications.isEmpty)
                          _buildEmptyState()
                        else
                          ..._buildNotificationSections(notifications),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GSWColors.borderSecondary),
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: IconButton(
          onPressed: () => context.pop(),
          icon: SvgPicture.asset(
            GSWIcons.arrowheadLeft,
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNotificationSections(List<Map<String, dynamic>> notifications) {
    // Unread notifications are shown once, in Latest, regardless of age.
    // Previously read notifications are grouped by local calendar day.
    final latest = <Map<String, dynamic>>[];
    final today = <Map<String, dynamic>>[];
    final yesterday = <Map<String, dynamic>>[];
    final earlier = <Map<String, dynamic>>[];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    for (final notification in notifications) {
      if (notification['is_read'] != true) {
        latest.add(notification);
        continue;
      }

      final createdAt = DateTime.tryParse(notification['created_at']?.toString() ?? '');
      if (createdAt == null) {
        earlier.add(notification);
        continue;
      }

      final local = createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day == todayStart) {
        today.add(notification);
      } else if (day == yesterdayStart) {
        yesterday.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    final sections = <Widget>[];

    void addSection(String label, List<Map<String, dynamic>> items) {
      if (items.isEmpty) return;
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 26));
      sections.add(_sectionLabel(label));
      sections.add(const SizedBox(height: 22));
      for (var index = 0; index < items.length; index++) {
        sections.add(_buildNotificationCard(items[index]));
        if (index != items.length - 1) {
          sections.add(const SizedBox(height: 12));
        }
      }
    }

    addSection('LATEST', latest);
    addSection('TODAY', today);
    addSection('YESTERDAY', yesterday);
    addSection('EARLIER', earlier);
    return sections;
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary));
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title']?.toString().trim() ?? '';
    final description = notification['body']?.toString().trim() ?? '';
    final isRead = notification['is_read'] == true;
    final createdAt = DateTime.tryParse(notification['created_at']?.toString() ?? '');
    return _NotificationCard(
      title: title,
      description: description,
      time: _relativeTime(createdAt),
      highlighted: !isRead,
      onTap: () {
        _openNotification(notification);
      },
    );
  }

  String _relativeTime(DateTime? value) {
    if (value == null) {
      return '';
    }
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) {
      return 'Now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return '${value.toLocal().day}/'
        '${value.toLocal().month}';
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Text(
              'No notifications yet',
              style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Updates about your matches and sessions will appear here.',
              textAlign: TextAlign.center,
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(),
            const SizedBox(height: 24),
            Text(
              'NOTIFICATIONS',
              style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
            ),
            const SizedBox(height: 48),
            Center(
              child: Text(
                'Unable to load notifications right now.',
                textAlign: TextAlign.center,
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Notification card
// -----------------------------------------------------------------------------
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.description,
    required this.time,
    required this.onTap,
    this.highlighted = false,
  });
  final String title;
  final String description;
  final String time;
  final VoidCallback onTap;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(12),
            border: highlighted ? Border.all(color: GSWColors.primary, width: 1) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: highlighted ? GSWColors.primary : GSWColors.textPrimary,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  time,
                  textAlign: TextAlign.right,
                  style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Scroll behaviour
// -----------------------------------------------------------------------------
class _NoScrollEffectBehavior extends ScrollBehavior {
  const _NoScrollEffectBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
