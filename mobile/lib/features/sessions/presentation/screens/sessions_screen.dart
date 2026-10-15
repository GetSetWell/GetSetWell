import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:mobile/features/sessions/presentation/screens/session_confirmation_flow.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sessions tab: Requests | Upcoming | Past (Figma 9.1, 10.5, 10.6).
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  static const _tabs = ['Requests', 'Upcoming', 'Past'];

  late final SessionsService _service;

  late int _selectedTab;

  late Future<List<Map<String, dynamic>>> _requestsFuture;
  late Future<List<Map<String, dynamic>>> _upcomingFuture;
  late Future<List<Map<String, dynamic>>> _pastFuture;

  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _service = SessionsService(Supabase.instance.client);
    _selectedTab = widget.initialTab.clamp(0, _tabs.length - 1);
    _loadAll();
  }

  void _loadAll() {
    _requestsFuture = _service.getConciergeRequests();
    _upcomingFuture = _service.getUpcomingSessions();
    _pastFuture = _service.getPastSessions();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(_loadAll);

    // Keep the pull-to-refresh spinner until the lists are back. Errors are
    // shown by the FutureBuilders, so never let them escape the refresh.
    try {
      await Future.wait([_requestsFuture, _upcomingFuture, _pastFuture]);
    } catch (_) {
      // The lists show their own error state.
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Opens a session and refreshes every list when the person comes back, so a
  /// move or cancel made on the detail screen shows straight away.
  Future<void> _openSession(String sessionId) async {
    if (sessionId.isEmpty || _isOpening) return;
    _isOpening = true;
    try {
      await context.push(GSWRoutes.sessionDetails, extra: sessionId);
    } finally {
      _isOpening = false;
    }
    await _refresh();
  }

  Future<void> _openRoute(String route, Object? extra) async {
    if (_isOpening) return;
    _isOpening = true;
    try {
      await context.push(route, extra: extra);
    } finally {
      _isOpening = false;
    }
    await _refresh();
  }

  Future<void> _openConfirmationFlow(Map<String, dynamic> session) async {
    await showSessionConfirmationFlow(
      context: context,
      session: session,
      onBookAgain: _startRepeatBooking,
      onFinished: _refresh,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: GSWColors.primary,
          backgroundColor: GSWColors.surfacePrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Figma shows Bebas 40 "SESSIONS"; the brief override keeps every
                // screen title in Outfit Bold 24.
                Text(
                  'Sessions',
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
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
      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.sessions),
    );
  }

  Widget _buildTabs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.full),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedTab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedTab == index ? GSWColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(GSWRadius.full),
                  ),
                  child: Text(
                    _tabs[index],
                    textAlign: TextAlign.center,
                    style: GSWTextStyles.labelMedium.copyWith(
                      height: 20 / 14,
                      color: _selectedTab == index
                          ? GSWColors.textInverse
                          : GSWColors.textSecondary,
                      fontWeight: _selectedTab == index ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 72),
      child: Center(child: CircularProgressIndicator(color: GSWColors.primary)),
    );
  }

  Widget _loadError(String title) {
    return _EmptyState(
      icon: GSWIcons.calendar,
      title: title,
      message: 'Check your connection and try again.',
      primaryLabel: 'Try again',
      onPrimary: _refresh,
    );
  }

  // ---------------------------------------------------------------------------
  // Requests (9.1, 9.1b, 9.1c)
  // ---------------------------------------------------------------------------

  Widget _buildRequests() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loading();

        if (snapshot.hasError) {
          debugPrint('Requests load failed: ${snapshot.error}');
          return _loadError('Could not load your requests');
        }

        final requests = (snapshot.data ?? []).map(_RequestView.new).toList();

        if (requests.isEmpty) {
          return _EmptyState(
            icon: GSWIcons.goal,
            title: 'No requests yet',
            message:
                'Tell us your goal, your area and when you can train. A real person reads it and recommends a trainer.',
            primaryLabel: 'Tell us your situation',
            onPrimary: () => _openRoute(GSWRoutes.helpMeChoose, null),
            compactTitle: true,
          );
        }

        final needsYou = requests.where((r) => r.state == _RequestState.recommendation).toList();
        final inProgress = requests.where((r) => r.state == _RequestState.finding).toList();
        final earlier = requests
            .where((r) => r.state == _RequestState.booked || r.state == _RequestState.closed)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._group('NEEDS YOU', needsYou.map(_buildRequestCard).toList()),
            ..._group('IN PROGRESS', inProgress.map(_buildRequestCard).toList()),
            ..._group('EARLIER', earlier.map(_buildRequestCard).toList()),
            Text(
              'You can have one open request at a time.',
              textAlign: TextAlign.center,
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
            ),
          ],
        );
      },
    );
  }

  /// A section label followed by its cards, all 12px apart (Figma list gap).
  List<Widget> _group(String label, List<Widget> cards) {
    if (cards.isEmpty) return const [];
    return [
      _SectionLabel(label),
      const SizedBox(height: 12),
      for (final card in cards) ...[card, const SizedBox(height: 12)],
    ];
  }

  Widget _buildRequestCard(_RequestView request) {
    final highlighted = request.state == _RequestState.recommendation;
    final trainer = request.trainerName;

    String? trainerLine;
    if (trainer != null) {
      if (request.state == _RequestState.recommendation) trainerLine = '$trainer picked for you';
      if (request.state == _RequestState.booked) trainerLine = 'Booked with $trainer';
    }

    late final String footer;
    late final String action;
    late final VoidCallback onTap;

    switch (request.state) {
      case _RequestState.recommendation:
        footer =
            'Take a look and book if ${request.pronoun} ${GSWPronoun.fitsVerb(request.trainerGender)}.';
        action = 'See your match';
        onTap = () => _openRoute(GSWRoutes.yourMatch, request.id);
      case _RequestState.finding:
        footer = "You'll hear by tomorrow morning.";
        action = 'See the request';
        onTap = () => _openRoute(GSWRoutes.conciergeRequestStatus, request.id);
      case _RequestState.booked:
        final start = request.sessionStartDubai;
        footer = start == null
            ? 'Session booked'
            : '${GSWTime.dayShort(start)}, ${GSWTime.timeRange(start, kSessionLength)}';
        action = 'View request';
        onTap = () {
          final sessionId = request.sessionId;
          if (sessionId != null && sessionId.isNotEmpty) {
            _openSession(sessionId);
          } else {
            _openRoute(GSWRoutes.conciergeRequestStatus, request.id);
          }
        };
      case _RequestState.closed:
        footer = request.sessionCancelled ? 'Session cancelled' : 'Request closed';
        action = 'View request';
        onTap = () {
          final sessionId = request.sessionId;
          if (sessionId != null) {
            _openSession(sessionId);
          } else if (request.hadRecommendation) {
            _openRoute(GSWRoutes.matchedTrainer, request.id);
          } else {
            _openRoute(GSWRoutes.conciergeRequestStatus, request.id);
          }
        };
    }

    final isEarlier =
        request.state == _RequestState.booked || request.state == _RequestState.closed;

    return _CardShell(
      onTap: onTap,
      highlighted: highlighted,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.statusLabel,
                  style: GSWTextStyles.bodySmall.copyWith(
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                    color: highlighted
                        ? GSWColors.textAccent
                        : request.state == _RequestState.finding
                            ? GSWColors.textPrimary
                            : GSWColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                request.referenceCode,
                style: GSWTextStyles.bodySmall.copyWith(
                  height: 16 / 12,
                  color: GSWColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            request.goalHeadline,
            style: isEarlier
                ? GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary, height: 1)
                : GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textPrimary,
                    fontSize: 17,
                    height: 22 / 17,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          if (request.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.details,
              style: (isEarlier ? GSWTextStyles.bodySmall : GSWTextStyles.bodyMedium).copyWith(
                fontSize: isEarlier ? 12 : 13,
                height: isEarlier ? 16 / 12 : 18 / 13,
                color: GSWColors.textSecondary,
              ),
            ),
          ],
          if (request.state == _RequestState.finding && request.sentLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              request.sentLabel!,
              style: GSWTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                height: 20 / 13,
                color: GSWColors.textSecondary,
              ),
            ),
          ],
          if (trainerLine != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                SessionTrainerAvatar(name: trainer!, imagePath: request.trainerImage),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trainerLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GSWTextStyles.bodyMedium.copyWith(
                      height: 20 / 14,
                      color: GSWColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      footerLeft: footer,
      footerLeftColor:
          isEarlier ? GSWColors.textSecondary : GSWColors.textPrimary,
      footerRight: action,
      footerRightColor: highlighted ? GSWColors.textAccent : GSWColors.textPrimary,
    );
  }

  // ---------------------------------------------------------------------------
  // Upcoming (10.5, 10.5a, 10.5b)
  // ---------------------------------------------------------------------------

  Widget _buildUpcoming() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _upcomingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loading();

        if (snapshot.hasError) {
          debugPrint('Upcoming sessions load failed: ${snapshot.error}');
          return _loadError('Could not load your sessions');
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return _EmptyState(
            icon: GSWIcons.calendar,
            title: 'No sessions booked',
            message:
                "When you book a session, it shows here with the time, the place and what you'd get back if you cancelled.",
            primaryLabel: 'Find a trainer',
            onPrimary: () => context.go(GSWRoutes.browseTrainers),
            secondaryLabel: 'Or tell us your situation',
            onSecondary: () => _openRoute(GSWRoutes.helpMeChoose, null),
          );
        }

        return Column(
          children: [
            for (var index = 0; index < sessions.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              _buildUpcomingCard(sessions[index], isNext: index == 0),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUpcomingCard(Map<String, dynamic> session, {required bool isNext}) {
    final start = sessionStartDubai(session);
    if (start == null) return const SizedBox.shrink();

    final trainer = SessionTrainerInfo.fromSession(session);
    final amounts = SessionAmounts.fromSession(session);
    final now = GSWTime.nowDubai();
    final remaining = start.difference(now);
    final started = remaining.isNegative;

    final label = started ? 'Happening now' : _relativeStart(start, now);

    final bool inside24h = !started && remaining < const Duration(hours: 24);

    final String footer;
    if (started) {
      footer = 'This session is under way. It ends at ${GSWTime.time(start.add(kSessionLength))}.';
    } else if (inside24h) {
      footer = amounts.halfRate == null
          ? 'Inside 24 hours: cancelling now returns half the session fee.'
          : 'Inside 24 hours: cancelling now returns ${GSWMoney.aed(amounts.halfRate)}, half the session fee.';
    } else {
      final cutoff = start.subtract(const Duration(hours: 24));
      footer = amounts.sessionRate == null
          ? 'Cancel before ${GSWTime.dayAndTime(cutoff)} to get the session fee back.'
          : 'Cancel before ${GSWTime.dayAndTime(cutoff)} to get the ${GSWMoney.aed(amounts.sessionRate)} session fee back.';
    }

    return _SessionCard(
      start: start,
      trainer: trainer,
      location: session['location_label']?.toString().trim() ?? '',
      label: label,
      labelColor: (isNext || started) ? GSWColors.textAccent : GSWColors.textSecondary,
      onTap: () => _openSession(session['id']?.toString() ?? ''),
      footer: Text(
        footer,
        style: GSWTextStyles.bodySmall.copyWith(
          height: 17 / 12,
          color: (inside24h || started) ? GSWColors.textPrimary : GSWColors.textSecondary,
        ),
      ),
    );
  }

  /// "Today · starts in 3 hours", "Tomorrow · starts in 21 hours", "In 3 days".
  String _relativeStart(DateTime start, DateTime now) {
    final remaining = start.difference(now);
    final dayGap = DateTime.utc(start.year, start.month, start.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;

    String startsIn() {
      if (remaining.inMinutes < 60) {
        final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
        return 'starts in $minutes min';
      }
      final hours = remaining.inHours;
      return 'starts in $hours ${hours == 1 ? 'hour' : 'hours'}';
    }

    if (dayGap <= 0) return 'Today · ${startsIn()}';
    if (dayGap == 1) return 'Tomorrow · ${startsIn()}';
    return 'In $dayGap days';
  }

  // ---------------------------------------------------------------------------
  // Past (10.6, 10.6b)
  // ---------------------------------------------------------------------------

  Widget _buildPast() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pastFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loading();

        if (snapshot.hasError) {
          debugPrint('Past sessions load failed: ${snapshot.error}');
          return _loadError('Could not load past sessions');
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return _EmptyState(
            icon: GSWIcons.calendar,
            title: 'No past sessions yet',
            message: "Once you've trained, your sessions and receipts will be here.",
            primaryLabel: 'Find a trainer',
            primaryVariant: GSWButtonVariant.secondary,
            onPrimary: () => context.go(GSWRoutes.browseTrainers),
          );
        }

        final needsYou = sessions.where(sessionNeedsConfirmation).toList();
        final earlier = sessions.where((s) => !sessionNeedsConfirmation(s)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._group('NEEDS YOU', needsYou.map((s) => _buildPastCard(s, needsAction: true)).toList()),
            ..._group('EARLIER', earlier.map(_buildPastCard).toList()),
          ],
        );
      },
    );
  }

  Widget _buildPastCard(Map<String, dynamic> session, {bool needsAction = false}) {
    final start = sessionStartDubai(session);
    if (start == null) return const SizedBox.shrink();

    final trainer = SessionTrainerInfo.fromSession(session);
    final status = sessionStatus(session);
    final cancelled = sessionIsCancelled(session);
    final reported = status == 'reported';
    final sessionId = session['id']?.toString() ?? '';

    final String label;
    if (needsAction) {
      label = _endedLabel(start);
    } else if (cancelled) {
      label = 'Cancelled';
    } else if (reported) {
      label = 'Reported';
    } else {
      label = 'Completed';
    }

    Widget footerLeft;
    String footerRight;
    Color footerRightColor = GSWColors.textPrimary;
    VoidCallback onRight;

    if (needsAction) {
      footerLeft = _footerText('Did this session take place?', GSWColors.textPrimary);
      footerRight = 'Tell us';
      footerRightColor = GSWColors.textAccent;
      onRight = () => _openConfirmationFlow(session);
    } else if (cancelled) {
      final refund = GSWMoney.parse(session['cancellation_refund_amount']);
      footerLeft = _footerText(
        refund == null || refund <= 0
            ? 'Session cancelled'
            : '${GSWMoney.aed(refund)} refunded to your card',
        GSWColors.textSecondary,
      );
      footerRight = 'View receipt';
      onRight = () => _openSession(sessionId);
    } else if (reported) {
      footerLeft = _footerText("We're looking into this", GSWColors.textSecondary);
      footerRight = 'View details';
      onRight = () => _openSession(sessionId);
    } else {
      footerLeft = InkWell(
        onTap: () => _startRepeatBooking(session),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _footerText('Book again', GSWColors.textAccent, weight: FontWeight.w500),
        ),
      );
      footerRight = 'View receipt';
      onRight = () => _openSession(sessionId);
    }

    return _SessionCard(
        start: start,
        trainer: trainer,
        location: session['location_label']?.toString().trim() ?? '',
        label: label,
        labelColor: needsAction
            ? GSWColors.textAccent
            : cancelled
                ? GSWColors.textTertiary
                : GSWColors.textSecondary,
        highlighted: needsAction,
        dimmed: cancelled,
        onTap: needsAction ? () => _openConfirmationFlow(session) : () => _openSession(sessionId),
        footer: Row(
          children: [
            Expanded(child: footerLeft),
            const SizedBox(width: 12),
            InkWell(
              onTap: onRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _footerText(footerRight, footerRightColor, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
    );
  }

  Widget _footerText(String text, Color color, {FontWeight weight = FontWeight.w400}) {
    return Text(
      text,
      style: GSWTextStyles.bodyMedium.copyWith(
        fontSize: 13,
        height: 18 / 13,
        color: color,
        fontWeight: weight,
      ),
    );
  }

  String _endedLabel(DateTime start) {
    final now = GSWTime.nowDubai();
    final days = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    if (days <= 0) return 'Ended today';
    if (days == 1) return 'Ended yesterday';
    return 'Ended $days days ago';
  }

  // ---------------------------------------------------------------------------
  // Book again
  // ---------------------------------------------------------------------------

  Future<void> _startRepeatBooking(Map<String, dynamic> session) async {
    final trainerId = session['trainer_id']?.toString().trim() ?? '';
    if (trainerId.isEmpty) {
      _showRepeatBookingError();
      return;
    }

    try {
      final trainers = await TrainerRepository(Supabase.instance.client).getTrainers();

      Trainer? selected;
      for (final trainer in trainers) {
        if (trainer.id == trainerId) {
          selected = trainer;
          break;
        }
      }

      if (!mounted) return;

      if (selected == null) {
        _showRepeatBookingError();
        return;
      }

      final request = session['booking_requests'];
      final requestMap = request is Map ? request : const {};

      String? firstNonEmpty(Object? a, Object? b) {
        final first = a?.toString().trim() ?? '';
        if (first.isNotEmpty) return first;
        final second = b?.toString().trim() ?? '';
        return second.isEmpty ? null : second;
      }

      await _openRoute(
        GSWRoutes.bookingRequest,
        BookingRequestRouteData(
          trainer: selected,
          initialGoal: firstNonEmpty(session['goal'], requestMap['goal']),
          initialTrainingPlace: BookingRequestRouteData.trainingPlaceFromDb(
            session['customer_training_place'],
          ),
          initialVenueChoice: BookingRequestRouteData.venueChoiceFromDb(session['venue_choice']),
          initialLocationLabel: session['location_label']?.toString().trim(),
          initialNotes: firstNonEmpty(session['notes'], requestMap['message']),
          isRepeatBooking: true,
        ),
      );
    } catch (error) {
      debugPrint('Could not start repeat booking: $error');
      _showRepeatBookingError();
    }
  }

  void _showRepeatBookingError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "We could not open this trainer's availability. Please try again.",
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),
          backgroundColor: GSWColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

// =============================================================================
// Request view model
// =============================================================================

enum _RequestState { recommendation, finding, booked, closed }

class _RequestView {
  _RequestView(this.raw);

  final Map<String, dynamic> raw;

  String get id => raw['id']?.toString() ?? '';

  String get status => raw['status']?.toString().trim().toLowerCase() ?? '';

  String get referenceCode {
    final value = raw['reference_code']?.toString().trim() ?? '';
    return value.isEmpty ? 'Request' : value;
  }

  Map<String, dynamic> get _trainer {
    final value = raw['trainers'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  String? get trainerName {
    final name = _trainer['full_name']?.toString().trim() ?? '';
    return name.isEmpty ? null : name;
  }

  String? get trainerImage => _trainer['profile_image_url']?.toString();

  Object? get trainerGender => _trainer['gender'];

  String get pronoun => GSWPronoun.subject(trainerGender);

  bool get hadRecommendation =>
      (raw['trainer_id']?.toString().trim().isNotEmpty ?? false) &&
      (raw['matched_at']?.toString().trim().isNotEmpty ?? false);

  /// The most recent session booked from this request.
  Map<String, dynamic>? get _session {
    final value = raw['sessions'];
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) {
      final list = value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      if (list.isEmpty) return null;
      list.sort((a, b) =>
          (b['scheduled_at']?.toString() ?? '').compareTo(a['scheduled_at']?.toString() ?? ''));
      return list.first;
    }
    return null;
  }

  String? get sessionId {
    final id = _session?['id']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  DateTime? get sessionStartDubai => GSWTime.parseToDubai(_session?['scheduled_at']);

  bool get sessionCancelled {
    final s = _session?['status']?.toString().trim().toLowerCase() ?? '';
    return s == 'cancelled' || s == 'canceled';
  }

  _RequestState get state {
    if (status == 'matched') return _RequestState.recommendation;

    if (_session != null && !sessionCancelled) return _RequestState.booked;
    if (status == 'confirmed' || status == 'booked') return _RequestState.booked;

    const closed = {'closed', 'cancelled', 'canceled', 'completed', 'lost'};
    if (closed.contains(status)) return _RequestState.closed;

    return _RequestState.finding;
  }

  String get statusLabel => switch (state) {
        _RequestState.recommendation => 'Recommendation ready',
        _RequestState.finding => 'Finding your trainer',
        _RequestState.booked => 'Session booked',
        _RequestState.closed => 'Closed',
      };

  String get goalHeadline {
    final goal = raw['goal']?.toString().trim() ?? '';
    switch (goal.toLowerCase()) {
      case 'lose weight':
        return 'Lose weight and build a routine';
      case 'get stronger':
        return 'Get stronger and build a routine';
      case 'move better':
        return 'Move better and build a routine';
      case 'back after a break':
        return 'Back after a break';
      case 'pre or postnatal':
        return 'Build a supported routine';
      case '':
      case 'something else':
        return 'Your trainer match';
      default:
        return GSWPronoun.capitalise(goal);
    }
  }

  String get details {
    final area = raw['preferred_area']?.toString().trim() ?? '';
    final time = raw['preferred_time']?.toString().trim() ?? '';
    final preference = raw['trainer_gender_preference']?.toString().trim() ?? '';

    final rawDays = raw['preferred_days'];
    final days = rawDays is List
        ? rawDays.map((d) => d.toString().trim()).where((d) => d.isNotEmpty).toList()
        : <String>[];

    final showPreference = state == _RequestState.recommendation || state == _RequestState.finding;

    return [
      if (area.isNotEmpty) area,
      if (time.isNotEmpty) _timeLabel(time, days),
      if (showPreference)
        (preference.isEmpty || preference.toLowerCase() == 'no preference' || preference.toLowerCase() == 'any')
            ? 'No preference'
            : '${GSWPronoun.capitalise(preference)} trainer',
    ].join(' · ');
  }

  String _timeLabel(String value, List<String> days) {
    final normalized = value.toLowerCase();
    const parts = {'morning': 'mornings', 'afternoon': 'afternoons', 'evening': 'evenings'};

    if (days.length == 1) {
      return '${GSWPronoun.capitalise(days.first)} ${parts.containsKey(normalized) ? normalized : value}';
    }

    final weekendOnly = days.isNotEmpty &&
        days.every((d) => const {'sat', 'saturday', 'sun', 'sunday'}.contains(d.toLowerCase()));

    if (parts.containsKey(normalized)) {
      return '${weekendOnly ? 'Weekend' : 'Weekday'} ${parts[normalized]}';
    }
    return GSWPronoun.capitalise(value);
  }

  String? get sentLabel {
    final sent = GSWTime.parseToDubai(raw['created_at']);
    if (sent == null) return null;
    final now = GSWTime.nowDubai();
    final String day;
    if (GSWTime.isSameDay(sent, now)) {
      day = 'today';
    } else if (GSWTime.isSameDay(sent, now.subtract(const Duration(days: 1)))) {
      day = 'yesterday';
    } else {
      day = 'on ${GSWTime.dayShort(sent)}';
    }
    return 'Sent $day at ${GSWTime.time(sent)}';
  }
}

// =============================================================================
// Shared pieces
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GSWTextStyles.bodySmall.copyWith(
        color: GSWColors.textTertiary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.96,
        height: 16 / 12,
      ),
    );
  }
}

/// Bordered card with a body and a footer row separated by a divider.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.onTap,
    required this.body,
    required this.footerLeft,
    required this.footerLeftColor,
    required this.footerRight,
    required this.footerRightColor,
    this.highlighted = false,
  });

  final VoidCallback onTap;
  final Widget body;
  final String footerLeft;
  final Color footerLeftColor;
  final String footerRight;
  final Color footerRightColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    TextStyle footerStyle(Color color, FontWeight weight) => GSWTextStyles.bodyMedium.copyWith(
          fontSize: 13,
          height: 18 / 13,
          color: color,
          fontWeight: weight,
        );

    return _TapCard(
      onTap: onTap,
      highlighted: highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: body),
          const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(footerLeft, style: footerStyle(footerLeftColor, FontWeight.w400))),
                const SizedBox(width: 12),
                Text(footerRight, style: footerStyle(footerRightColor, FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapCard extends StatelessWidget {
  const _TapCard({required this.onTap, required this.child, this.highlighted = false});

  final VoidCallback onTap;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
            border: Border.all(
              color: highlighted ? GSWColors.primary : GSWColors.surfaceInteractive,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Session card used by Upcoming and Past (10.5a, 10.6).
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.start,
    required this.trainer,
    required this.location,
    required this.label,
    required this.labelColor,
    required this.onTap,
    required this.footer,
    this.highlighted = false,
    this.dimmed = false,
  });

  final DateTime start;
  final SessionTrainerInfo trainer;
  final String location;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final Widget footer;
  final bool highlighted;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final textColor = dimmed ? GSWColors.textSecondary : GSWColors.textPrimary;

    return _TapCard(
      onTap: onTap,
      highlighted: highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _DateBlock(start: start, dimmed: dimmed),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GSWTextStyles.bodySmall.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                          height: 16 / 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        GSWTime.timeRange(start, kSessionLength),
                        style: GSWTextStyles.titleExtraSmall.copyWith(
                          fontSize: 17,
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          height: 22 / 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SessionTrainerAvatar(name: trainer.name, imagePath: trainer.imagePath),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${trainer.name} · ${trainer.serviceLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GSWTextStyles.bodyMedium.copyWith(
                                color: textColor,
                                height: 20 / 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [if (location.isNotEmpty) location, '60 min'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GSWTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          color: GSWColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: footer,
          ),
        ],
      ),
    );
  }
}

/// 56 wide, stretched to the details column (16 + 6 + 22 + 6 + 24 + 6 + 18).
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.start, this.dimmed = false});

  final DateTime start;

  /// Cancelled cards draw the whole block in text/secondary.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final small = GSWTextStyles.bodyExtraSmall.copyWith(
      color: GSWColors.textSecondary,
      fontWeight: FontWeight.w500,
      height: 14 / 11,
    );

    return Container(
      width: 56,
      height: 98,
      decoration: BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(GSWRadius.inner),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(GSWTime.weekdayShort(start).toUpperCase(), style: small),
          Text(
            '${start.day}',
            style: GSWTextStyles.headingLarge.copyWith(
              color: dimmed ? GSWColors.textSecondary : GSWColors.textPrimary,
              height: 32 / 30,
            ),
          ),
          Text(GSWTime.monthShort(start).toUpperCase(), style: small),
        ],
      ),
    );
  }
}

/// Empty and error states (9.1c, 10.5b, 10.6b): 56px icon tile, title, line,
/// then the actions.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryVariant = GSWButtonVariant.primary,
    this.secondaryLabel,
    this.onSecondary,
    this.compactTitle = false,
  });

  /// 9.1c draws the heading at 18 / 18; 10.5b and 10.6b at SemiBold 18 / 24.
  final bool compactTitle;

  final String icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final GSWButtonVariant primaryVariant;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72, bottom: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: GSWColors.surfacePrimary,
              borderRadius: BorderRadius.circular(GSWRadius.card),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              icon,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: compactTitle
                ? GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary, height: 1)
                : GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 24 / 18,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              height: 20 / 14,
            ),
          ),
          // 12 gap + 8 spacer + 12 gap in every empty state frame.
          const SizedBox(height: 32),
          GSWButton(label: primaryLabel, variant: primaryVariant, onPressed: onPrimary),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            GSWButton(
              label: secondaryLabel!,
              variant: GSWButtonVariant.tertiary,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}
