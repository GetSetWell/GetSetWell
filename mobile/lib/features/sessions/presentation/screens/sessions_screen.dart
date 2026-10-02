import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:mobile/features/booking/data/services/booking_request_service.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  int _selectedTab = 0;

  static const _tabs = ['Requests', 'Upcoming', 'Past'];

  late final BookingRequestService _bookingRequestService;

  late Future<List<Map<String, dynamic>>> _requestsFuture;

  late final SessionsService _sessionsService;

  late Future<List<Map<String, dynamic>>> _upcomingSessionsFuture;

  late Future<List<Map<String, dynamic>>> _pastSessionsFuture;

  @override
  void initState() {
    super.initState();

    _bookingRequestService = BookingRequestService(Supabase.instance.client);

    _requestsFuture = _bookingRequestService.getMyRequests();

    _sessionsService = SessionsService(Supabase.instance.client);

    _upcomingSessionsFuture = _sessionsService.getUpcomingSessions();

    _pastSessionsFuture = _loadPastSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),

                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        'SESSIONS',

                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 20),

                      _buildTabs(),

                      const SizedBox(height: 20),

                      if (_selectedTab == 0) _buildRequests(),

                      if (_selectedTab == 1) _buildUpcoming(),

                      if (_selectedTab == 2) _buildPast(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.sessions),
    );
  }

  Widget _buildTabs() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(999),
      ),

      child: Row(
        children: List.generate(_tabs.length, (index) {
          final selected = _selectedTab == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                });
              },

              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),

                padding: const EdgeInsets.symmetric(vertical: 10),

                decoration: BoxDecoration(
                  color: selected ? GSWColors.primary : Colors.transparent,

                  borderRadius: BorderRadius.circular(999),
                ),

                child: Text(
                  _tabs[index],

                  textAlign: TextAlign.center,

                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? GSWColors.backgroundPrimary : GSWColors.textSecondary,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRequests() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),

              child: CircularProgressIndicator(color: GSWColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Sessions requests load failed: ${snapshot.error}');

          return _buildEmptyState(
            title: 'Could not load requests.',

            message: 'Please try again in a moment.',
          );
        }

        final requests = (snapshot.data ?? [])
            .where((request) => request['request_type']?.toString().trim() == 'concierge_match')
            .toList();

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: GSWIcons.goal,

            title: 'No requests yet',

            message:
                'Tell us your goal, your area and when you can train. A real person reads it and recommends a trainer.',

            ctaLabel: 'Tell us your situation',

            onCtaPressed: () {
              context.push(GSWRoutes.helpMeChoose);
            },
          );
        }

        final inProgress = requests.where((request) {
          final status = request['status']?.toString().trim().toLowerCase() ?? '';

          return _isOpenRequest(request) && status != 'matched';
        }).toList();

        final needsYou = requests.where((request) {
          final status = request['status']?.toString().trim().toLowerCase() ?? '';

          return status == 'matched';
        }).toList();

        final earlier = requests.where((request) {
          final status = request['status']?.toString().trim().toLowerCase() ?? '';

          return !_isOpenRequest(request) && status != 'matched';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            if (inProgress.isNotEmpty) ...[
              _buildSectionLabel('IN PROGRESS'),

              const SizedBox(height: 14),

              for (var index = 0; index < inProgress.length; index++) ...[
                _buildRequestFromData(inProgress[index], showSentAt: true),

                if (index != inProgress.length - 1) const SizedBox(height: 16),
              ],

              if (needsYou.isNotEmpty || earlier.isNotEmpty) const SizedBox(height: 26),
            ],

            if (needsYou.isNotEmpty) ...[
              _buildSectionLabel('NEEDS YOU'),

              const SizedBox(height: 14),

              for (var index = 0; index < needsYou.length; index++) ...[
                _buildRequestFromData(needsYou[index], highlighted: true),

                if (index != needsYou.length - 1) const SizedBox(height: 16),
              ],

              if (earlier.isNotEmpty) const SizedBox(height: 26),
            ],

            if (earlier.isNotEmpty) ...[
              _buildSectionLabel('EARLIER'),

              const SizedBox(height: 14),

              for (var index = 0; index < earlier.length; index++) ...[
                _buildRequestFromData(earlier[index]),

                if (index != earlier.length - 1) const SizedBox(height: 16),
              ],
            ],

            const SizedBox(height: 24),

            Center(
              child: Text(
                'You can have one open request at a time.',

                textAlign: TextAlign.center,

                style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestFromData(
    Map<String, dynamic> request, {

    bool highlighted = false,

    bool showSentAt = false,
  }) {
    final status = request['status']?.toString().trim().toLowerCase() ?? '';

    final referenceCode = request['reference_code']?.toString().trim() ?? 'Request';

    final goal = request['goal']?.toString().trim().isNotEmpty == true
        ? request['goal'].toString().trim()
        : 'Trainer request';

    final area = request['preferred_area']?.toString().trim() ?? '';

    final time = request['preferred_time']?.toString().trim() ?? '';

    final preference = request['trainer_gender_preference']?.toString().trim() ?? '';

    final createdAt = DateTime.tryParse(request['created_at']?.toString() ?? '');

    final sentAtLabel = createdAt == null ? null : _requestSentAtLabel(createdAt);

    final trainer = request['trainers'];

    String? trainerName;

    String? trainerImage;

    if (trainer is Map) {
      trainerName = trainer['full_name']?.toString().trim();

      trainerImage = trainer['profile_image_url']?.toString().trim();
    }

    final rawDays = request['preferred_days'];

    final preferredDays = rawDays is List
        ? rawDays.map((day) => day.toString().trim()).where((day) => day.isNotEmpty).toList()
        : <String>[];

    final details = [
      if (area.isNotEmpty) area,

      if (time.isNotEmpty) _requestTimeLabel(time, preferredDays),

      if (preference.isNotEmpty) '${_capitalize(preference)} preference' else 'No preference',
    ].join(' · ');

    final isMatched = status == 'matched';
    final isBooked = status == 'confirmed' || status == 'booked';
    final isMatchingInProgress = _isOpenRequest(request) && !isMatched;

    final footerText = isMatched
        ? 'Take a look and book if he fits.'
        : isMatchingInProgress
        ? 'You\'ll hear by tomorrow.'
        : _requestFooter(status, trainerName);

    final actionLabel = isMatched
        ? 'See your match'
        : isMatchingInProgress
        ? 'See the Request'
        : 'View Request';

    void onTap() {
      if (isMatched) {
        context.push(GSWRoutes.yourMatch, extra: request['id']?.toString() ?? '');
        return;
      }
      if (isMatchingInProgress) {
        context.push(GSWRoutes.conciergeRequestStatus, extra: request['id']?.toString() ?? '');

        return;
      }
      if (isBooked) {
        _openBookedRequestSession(request);
        return;
      }
      _openConciergeRequest(request);
    }

    return _buildRequestCard(
      referenceCode: referenceCode,

      status: _requestStatusLabel(status),

      goal: _goalHeadline(goal),

      details: details,

      trainerName: trainerName,

      trainerImage: trainerImage,

      isMatched: isMatched,

      footer: footerText,

      actionLabel: actionLabel,

      highlighted: highlighted,

      sentAtLabel: showSentAt ? sentAtLabel : null,

      onTap: onTap,
    );
  }

  void _openConciergeRequest(Map<String, dynamic> request) {
    context.push(GSWRoutes.conciergeRequestStatus, extra: request['id']?.toString() ?? '');
  }

  Widget _buildUpcoming() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _upcomingSessionsFuture,

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),

              child: CircularProgressIndicator(color: GSWColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Upcoming sessions load failed: ${snapshot.error}');

          return _buildEmptyState(
            title: 'Could not load sessions.',

            message: 'Please try again in a moment.',
          );
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return _buildEmptyState(
            icon: GSWIcons.calendar,

            title: 'No upcoming sessions',

            message:
                'When you book a session, it shows here with the time, the place and what you\'d get back if you cancelled.',

            ctaLabel: 'Find a trainer',

            onCtaPressed: () {
              context.go(GSWRoutes.browseTrainers);
            },
          );
        }

        return Column(
          children: [
            for (var index = 0; index < sessions.length; index++) ...[
              _buildUpcomingSessionCard(sessions[index]),

              if (index != sessions.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUpcomingSessionCard(Map<String, dynamic> session) {
    final trainer = session['trainers'];

    String trainerName = 'Your trainer';

    const specialty = 'Personal training';

    String? profileImageUrl;

    if (trainer is Map) {
      final name = trainer['full_name']?.toString().trim();

      final imageUrl = trainer['profile_image_url']?.toString().trim();

      if (name != null && name.isNotEmpty) trainerName = name;

      if (imageUrl != null && imageUrl.isNotEmpty) profileImageUrl = imageUrl;
    }

    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

    final location = session['location_label']?.toString().trim() ?? '';

    if (scheduledAt == null) return const SizedBox.shrink();

    final dubaiStart = _toDubai(scheduledAt);

    final dubaiEnd = dubaiStart.add(const Duration(hours: 1));

    final relativeLabel = _sessionRelativeLabel(dubaiStart);

    final isSoon = _isSessionSoon(dubaiStart);

    final nowDubai = _toDubai(DateTime.now());

    final remaining = dubaiStart.difference(nowDubai);

    final cutoff = dubaiStart.subtract(const Duration(hours: 24));

    return _tapCard(
      onTap: () => _handleSessionCardTap(session),

      borderColor: GSWColors.surfaceInteractive,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.all(16),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                _buildSessionDateBlock(dubaiStart),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        relativeLabel,

                        style: GSWTextStyles.bodySmall.copyWith(
                          color: isSoon ? GSWColors.primary : GSWColors.textSecondary,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        '${_sessionTimeLabel(dubaiStart)} to ${_sessionTimeLabel(dubaiEnd)}',

                        style: GSWTextStyles.labelLarge.copyWith(
                          color: GSWColors.textPrimary,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          _buildTrainerAvatar(trainerName, profileImageUrl),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              '$trainerName · $specialty',

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: GSWTextStyles.bodyMedium.copyWith(
                                color: GSWColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        [if (location.isNotEmpty) location, '60 min'].join(' · '),

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: GSWColors.neutral700),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

            child: remaining <= const Duration(hours: 24) && !remaining.isNegative
                ? Text(
                    'Inside 24 hours: your cancellation policy applies to this session.',

                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textPrimary),
                  )
                : Text(
                    'Cancel before ${_cancellationCutoffLabel(cutoff)} to stay outside the 24-hour cancellation window.',

                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDateBlock(DateTime dubaiStart) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    const months = [
      'JAN',

      'FEB',

      'MAR',

      'APR',

      'MAY',

      'JUN',

      'JUL',

      'AUG',

      'SEP',

      'OCT',

      'NOV',

      'DEC',
    ];

    return Container(
      width: 56,

      height: 98,

      decoration: BoxDecoration(
        color: GSWColors.backgroundPrimary,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Text(
            weekdays[dubaiStart.weekday - 1],

            style: GSWTextStyles.bodyExtraSmall.copyWith(
              color: GSWColors.textSecondary,

              fontWeight: FontWeight.w600,
            ),
          ),

          Text(
            '${dubaiStart.day}',

            style: GSWTextStyles.headingLarge.copyWith(color: GSWColors.textPrimary),
          ),

          Text(
            months[dubaiStart.month - 1],

            style: GSWTextStyles.bodyExtraSmall.copyWith(
              color: GSWColors.textSecondary,

              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerAvatar(String trainerName, String? profileImageUrl) {
    String? resolvedUrl;

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      resolvedUrl = Supabase.instance.client.storage
          .from('trainer-images')
          .getPublicUrl(profileImageUrl);
    }

    final hasImage = resolvedUrl != null && resolvedUrl.isNotEmpty;

    return Container(
      width: 32,

      height: 32,

      decoration: const BoxDecoration(shape: BoxShape.circle, color: GSWColors.surfaceInteractive),

      child: ClipOval(
        child: hasImage
            ? Image.network(
                resolvedUrl,

                width: 32,

                height: 32,

                fit: BoxFit.cover,

                alignment: const Alignment(0, -0.8),
              )
            : Center(
                child: Text(
                  trainerName.isEmpty ? 'T' : trainerName[0].toUpperCase(),

                  style: GSWTextStyles.bodyExtraSmall.copyWith(
                    color: GSWColors.primary,

                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  DateTime _toDubai(DateTime value) {
    return value.toUtc().add(const Duration(hours: 4));
  }

  String _sessionRelativeLabel(DateTime dubaiStart) {
    final nowDubai = _toDubai(DateTime.now());

    final today = DateTime(nowDubai.year, nowDubai.month, nowDubai.day);

    final sessionDay = DateTime(dubaiStart.year, dubaiStart.month, dubaiStart.day);

    final dayDifference = sessionDay.difference(today).inDays;

    final remaining = dubaiStart.difference(nowDubai);

    if (dayDifference == 0) {
      if (!remaining.isNegative) {
        final hours = remaining.inHours;

        if (hours < 1) {
          final minutes = remaining.inMinutes.clamp(0, 59);

          return 'Today · starts in $minutes min';
        }

        return 'Today · starts in $hours ${hours == 1 ? 'hour' : 'hours'}';
      }

      return 'Today';
    }

    if (dayDifference == 1) {
      final hours = remaining.inHours;

      return 'Tomorrow · starts in $hours ${hours == 1 ? 'hour' : 'hours'}';
    }

    if (dayDifference > 1) {
      return 'In $dayDifference days';
    }

    return 'Upcoming';
  }

  bool _isSessionSoon(DateTime dubaiStart) {
    final nowDubai = _toDubai(DateTime.now());

    final remaining = dubaiStart.difference(nowDubai);

    return !remaining.isNegative && remaining <= const Duration(hours: 48);
  }

  String _sessionTimeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

    final minute = value.minute.toString().padLeft(2, '0');

    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _cancellationCutoffLabel(DateTime value) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    const months = [
      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',
    ];

    return '${weekdays[value.weekday - 1]} '
        '${value.day} ${months[value.month - 1]}, '
        '${_sessionTimeLabel(value)}';
  }

  String _goalHeadline(String? goal) {
    final normalized = goal?.trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'lose weight':
        return 'Lose weight and build a routine';

      case 'get stronger':
        return 'Get stronger and build a routine';

      case 'move better':
        return 'Move better and build a routine';

      case 'back after a break':
        return 'Get back into a routine';

      case 'pre or postnatal':
        return 'Build a supported routine';

      case 'something else':
        return 'Your trainer match';

      default:
        if (normalized.isEmpty) {
          return 'Your trainer match';
        }

        return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
    }
  }

  String _requestSentAtLabel(DateTime value) {
    final dubai = _toDubai(value);

    final nowDubai = _toDubai(DateTime.now());

    final today = DateTime(nowDubai.year, nowDubai.month, nowDubai.day);

    final sentDay = DateTime(dubai.year, dubai.month, dubai.day);

    final dayDifference = today.difference(sentDay).inDays;

    final dayLabel = switch (dayDifference) {
      0 => 'today',

      1 => 'yesterday',

      _ => '${dubai.day} ${_shortMonthLabel(dubai.month)}',
    };

    return 'Sent $dayLabel at ${_sessionTimeLabel(dubai)}';
  }

  String _shortMonthLabel(int month) {
    const months = [
      'Jan',

      'Feb',

      'Mar',

      'Apr',

      'May',

      'Jun',

      'Jul',

      'Aug',

      'Sep',

      'Oct',

      'Nov',

      'Dec',
    ];

    return months[month - 1];
  }

  String _requestStatusLabel(String status) {
    switch (status) {
      case 'matched':
        return 'Recommendation ready';

      case 'confirmed':
      case 'booked':
        return 'Booked';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      case 'completed':
        return 'Completed';

      default:
        return 'Matching in progress';
    }
  }

  String _requestFooter(String status, String? trainerName) {
    if ((status == 'confirmed' || status == 'booked') && trainerName?.isNotEmpty == true) {
      return 'Booked with $trainerName';
    }

    if (status == 'cancelled' || status == 'canceled') {
      return 'Request cancelled';
    }

    return 'We are finding the right trainer for you';
  }

  bool _isOpenRequest(Map<String, dynamic> request) {
    final status = request['status']?.toString().trim().toLowerCase() ?? '';

    const closedStatuses = {'closed', 'cancelled', 'canceled', 'completed', 'confirmed', 'lost'};

    return !closedStatuses.contains(status);
  }

  String _capitalize(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  Widget _buildRequestCard({
    required String referenceCode,

    required String status,

    required String goal,

    required String details,

    required String footer,

    required bool isMatched,

    required String actionLabel,

    required VoidCallback onTap,

    String? trainerName,

    String? trainerImage,

    String? sentAtLabel,

    bool highlighted = false,
  }) {
    return _tapCard(
      onTap: onTap,

      borderColor: highlighted ? GSWColors.primary : GSWColors.surfaceInteractive,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,

                        style: GSWTextStyles.bodySmall.copyWith(
                          color: highlighted
                              ? GSWColors.primary
                              : isMatched
                              ? GSWColors.textSecondary
                              : GSWColors.textPrimary,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    Text(
                      referenceCode,

                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  goal,

                  style: GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textPrimary,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (details.isNotEmpty) ...[
                  const SizedBox(height: 6),

                  Text(
                    details,

                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),
                ],

                if (sentAtLabel?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),

                  Text(
                    sentAtLabel!,

                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                  ),
                ],

                if (trainerName?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _buildTrainerAvatar(trainerName!, trainerImage),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          highlighted ? '$trainerName picked for you' : 'Booked with $trainerName',

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: GSWColors.neutral700),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    footer,

                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: isMatched ? GSWColors.textSecondary : GSWColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  actionLabel,

                  style: GSWTextStyles.bodyMedium.copyWith(
                    color: highlighted ? GSWColors.primary : GSWColors.textPrimary,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPast() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pastSessionsFuture,

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),

              child: CircularProgressIndicator(color: GSWColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Past sessions load failed: ${snapshot.error}');

          return _buildEmptyState(
            title: 'Could not load past sessions.',

            message: 'Please try again in a moment.',
          );
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return _buildEmptyState(
            icon: GSWIcons.calendar,

            title: 'No past sessions yet',

            message: 'Once you’ve trained, your sessions and receipts will be here.',

            ctaLabel: 'Find a trainer',

            onCtaPressed: () {
              context.go(GSWRoutes.browseTrainers);
            },
          );
        }

        final needsYou = sessions.where((session) {
          final status = session['status']?.toString().trim().toLowerCase() ?? '';

          return status == 'confirmed' || status == 'booked';
        }).toList();

        final earlier = sessions.where((session) {
          final status = session['status']?.toString().trim().toLowerCase() ?? '';

          return status != 'confirmed' && status != 'booked';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            if (needsYou.isNotEmpty) ...[
              _buildSectionLabel('NEEDS YOU'),

              const SizedBox(height: 14),

              for (var index = 0; index < needsYou.length; index++) ...[
                _buildPastSessionCard(needsYou[index], needsAction: true),

                if (index != needsYou.length - 1) const SizedBox(height: 16),
              ],

              if (earlier.isNotEmpty) const SizedBox(height: 26),
            ],

            if (earlier.isNotEmpty) ...[
              _buildSectionLabel('EARLIER'),

              const SizedBox(height: 14),

              for (var index = 0; index < earlier.length; index++) ...[
                _buildPastSessionCard(earlier[index]),

                if (index != earlier.length - 1) const SizedBox(height: 16),
              ],
            ],
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadPastSessions() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return [];

    final rows = await Supabase.instance.client
        .from('sessions')
        .select('''
  id,
  reference_code,
  request_type,
  status,
  goal,
  preferred_days,
  preferred_time,
  preferred_area,
  trainer_gender_preference,
  budget_min,
  budget_max,
  language_preference,
  message,
  trainer_id,
  match_outcome,
  match_reason,
  matched_at,
  training_locations(name),
  trainers(
    full_name,
    profile_image_url,
    price_per_session
  )
''')
        .eq('user_id', user.id)
        .order('scheduled_at', ascending: false);

    final nowUtc = DateTime.now().toUtc();

    return rows.map((row) => Map<String, dynamic>.from(row)).where((session) {
      final status = session['status']?.toString().trim().toLowerCase() ?? '';

      final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

      final closedStatus = {'completed', 'cancelled', 'canceled'}.contains(status);

      final hasEnded =
          scheduledAt != null && scheduledAt.toUtc().add(const Duration(hours: 1)).isBefore(nowUtc);

      return closedStatus || hasEnded;
    }).toList();
  }

  Widget _buildPastSessionCard(Map<String, dynamic> session, {bool needsAction = false}) {
    final trainer = session['trainers'];

    String trainerName = 'Your trainer';

    String? profileImageUrl;

    if (trainer is Map) {
      final name = trainer['full_name']?.toString().trim();

      final imageUrl = trainer['profile_image_url']?.toString().trim();

      if (name != null && name.isNotEmpty) trainerName = name;

      if (imageUrl != null && imageUrl.isNotEmpty) profileImageUrl = imageUrl;
    }

    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

    final location = session['location_label']?.toString().trim() ?? '';

    final status = session['status']?.toString().trim().toLowerCase() ?? '';

    if (scheduledAt == null) return const SizedBox.shrink();

    final dubaiStart = _toDubai(scheduledAt);

    final dubaiEnd = dubaiStart.add(const Duration(hours: 1));

    final cancelled = status == 'cancelled' || status == 'canceled';

    final completed = status == 'completed';

    final statusLabel = needsAction
        ? _endedRelativeLabel(dubaiStart)
        : cancelled
        ? 'Cancelled'
        : completed
        ? 'Completed'
        : _capitalize(status);

    final footerLeft = needsAction
        ? 'Did this session take place?'
        : cancelled
        ? 'Session cancelled'
        : 'Book again';

    final footerRight = needsAction ? 'Tell us' : 'View receipt';

    return Opacity(
      opacity: cancelled ? 0.72 : 1,

      child: _tapCard(
        onTap: () => _handleSessionCardTap(session),

        borderColor: needsAction ? GSWColors.primary : GSWColors.surfaceInteractive,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Padding(
              padding: const EdgeInsets.all(16),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  _buildSessionDateBlock(dubaiStart),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          statusLabel,

                          style: GSWTextStyles.bodySmall.copyWith(
                            color: needsAction ? GSWColors.primary : GSWColors.textSecondary,

                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          '${_sessionTimeLabel(dubaiStart)} to ${_sessionTimeLabel(dubaiEnd)}',

                          style: GSWTextStyles.labelLarge.copyWith(
                            color: GSWColors.textPrimary,

                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            _buildTrainerAvatar(trainerName, profileImageUrl),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                '$trainerName · Personal training',

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                                style: GSWTextStyles.bodyMedium.copyWith(
                                  color: GSWColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          [if (location.isNotEmpty) location, '60 min'].join(' · '),

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: GSWColors.neutral700),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      footerLeft,

                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: needsAction
                            ? GSWColors.textPrimary
                            : cancelled
                            ? GSWColors.textSecondary
                            : GSWColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Text(
                    footerRight,

                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: needsAction ? GSWColors.primary : GSWColors.textPrimary,

                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,

      style: GSWTextStyles.bodySmall.copyWith(
        color: GSWColors.textSecondary,

        fontWeight: FontWeight.w600,

        letterSpacing: 0.8,

        height: 1.3,
      ),
    );
  }

  Widget _tapCard({
    required VoidCallback onTap,

    required Widget child,

    required Color borderColor,
  }) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        child: Ink(
          width: double.infinity,

          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: borderColor),
          ),

          child: child,
        ),
      ),
    );
  }

  void _handleSessionCardTap(Map<String, dynamic> session) {
    context.push(GSWRoutes.sessionDetails, extra: session['id']?.toString() ?? '');
  }

  Future<void> _openBookedRequestSession(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString().trim() ?? '';

    if (requestId.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) return;

      final session = await Supabase.instance.client
          .from('sessions')
          .select('id')
          .eq('booking_request_id', requestId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted || session == null) return;

      final sessionId = session['id']?.toString().trim() ?? '';

      if (sessionId.isEmpty) return;

      context.push(GSWRoutes.sessionDetails, extra: sessionId);
    } catch (error) {
      debugPrint('Could not open booked request session: $error');
    }
  }

  String _requestTimeLabel(String value, List<String> preferredDays) {
    final normalizedTime = value.trim().toLowerCase();

    if (preferredDays.length == 1) {
      final day = _capitalize(preferredDays.first);

      switch (normalizedTime) {
        case 'morning':
          return '$day morning';

        case 'afternoon':
          return '$day afternoon';

        case 'evening':
          return '$day evening';

        default:
          return '$day ${_capitalize(value)}';
      }
    }

    switch (normalizedTime) {
      case 'morning':
        return 'Weekday mornings';

      case 'afternoon':
        return 'Weekday afternoons';

      case 'evening':
        return 'Weekday evenings';

      default:
        return _capitalize(value);
    }
  }

  String _endedRelativeLabel(DateTime dubaiStart) {
    final nowDubai = _toDubai(DateTime.now());

    final today = DateTime(nowDubai.year, nowDubai.month, nowDubai.day);

    final sessionDay = DateTime(dubaiStart.year, dubaiStart.month, dubaiStart.day);

    final difference = today.difference(sessionDay).inDays;

    if (difference == 0) return 'Ended today';

    if (difference == 1) return 'Ended yesterday';

    return 'Ended $difference days ago';
  }

  Widget _buildEmptyState({
    required String title,

    required String message,

    String? icon,

    String? ctaLabel,

    VoidCallback? onCtaPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),

      child: Center(
        child: Column(
          children: [
            if (icon != null) ...[
              Container(
                width: 72,

                height: 72,

                decoration: BoxDecoration(
                  color: GSWColors.surfacePrimary,

                  borderRadius: BorderRadius.circular(18),
                ),

                child: Center(
                  child: SvgPicture.asset(
                    icon,

                    width: 20,

                    height: 20,

                    colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],

            Text(
              title,

              textAlign: TextAlign.center,

              style: GSWTextStyles.titleExtraSmall.copyWith(
                color: GSWColors.textPrimary,

                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),

              child: Text(
                message,

                textAlign: TextAlign.center,

                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary, height: 1.5),
              ),
            ),

            if (ctaLabel != null && onCtaPressed != null) ...[
              const SizedBox(height: 32),

              GSWButton(
                size: GSWButtonSize.large,

                variant: GSWButtonVariant.secondary,

                label: ctaLabel,

                onPressed: onCtaPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
