import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/common/header.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/sessions/presentation/screens/session_confirmation_flow.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_card.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_matching_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../trainers/data/repositories/trainer_repository.dart';
import '../../../trainers/domain/models/trainer.dart';

/// Figma Story 7 Home:
/// - 7.1 match waiting (818:2706): "Recommendation ready" card leads, no
///   Help me choose card (a request is already open).
/// - 7.2 session upcoming (818:2870) / Open request card (998:3109):
///   "Next session" card leads, then greeting, Help me choose.
/// - 7.3 nothing pending (818:3034): greeting, Help me choose.
/// - 7.4 request in progress (818:3198): "Matching in progress" card leads,
///   Help me choose becomes "Your request is being reviewed".
/// Featured trainers follow in every state.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Sessions are fixed at 60 minutes (current policy).
  static const Duration _sessionLength = Duration(hours: 1);

  late final SupabaseClient _client;
  late final TrainerRepository _trainerRepository;

  late Future<List<Trainer>> _featuredTrainersFuture;
  late Future<_HomeData> _homeDataFuture;

  bool _didCheckSessionPrompt = false;

  @override
  void initState() {
    super.initState();

    _client = Supabase.instance.client;
    _trainerRepository = TrainerRepository(_client);

    _featuredTrainersFuture = _trainerRepository.getFeaturedTrainers();
    _homeDataFuture = _loadHomeData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPendingSessionPrompt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: RefreshIndicator(
            color: GSWColors.primary,
            backgroundColor: GSWColors.surfacePrimary,
            onRefresh: _refreshHomeData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: FutureBuilder<_HomeData>(
                future: _homeDataFuture,
                builder: (context, snapshot) {
                  final homeLoaded = snapshot.hasData;
                  final homeData = snapshot.data ?? const _HomeData();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSections(homeData, homeLoaded: homeLoaded),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.home),
    );
  }

  /// Sections separated by the 28px gap from the Figma "Scroll" frame.
  List<Widget> _buildSections(_HomeData data, {required bool homeLoaded}) {
    final sections = <Widget>[const SizedBox(height: 36, child: Header())];

    final priorityCard = _buildPriorityCard(data);

    if (priorityCard != null) {
      sections.add(priorityCard);
    }

    sections.add(_buildGreeting(data));

    final helpCard = homeLoaded ? _buildHelpMeChooseCard(data) : null;

    if (helpCard != null) {
      sections.add(helpCard);
    }

    sections.add(_buildFeaturedTrainers());

    final spaced = <Widget>[];

    for (int index = 0; index < sections.length; index++) {
      if (index > 0) spaced.add(const SizedBox(height: 28));
      spaced.add(sections[index]);
    }

    return spaced;
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<void> _refreshHomeData() async {
    final homeFuture = _loadHomeData();
    final featuredFuture = _trainerRepository.getFeaturedTrainers();

    if (mounted) {
      setState(() {
        _homeDataFuture = homeFuture;
        _featuredTrainersFuture = featuredFuture;
      });
    }

    try {
      await Future.wait<Object?>([homeFuture, featuredFuture]);
    } catch (error) {
      debugPrint('Home refresh failed: $error');
    }
  }

  Future<_HomeData> _loadHomeData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _HomeData();
    }

    String customerId;

    try {
      customerId = await CustomerIdentityService(client: _client).getCustomerId();
    } catch (error) {
      debugPrint('Home customer id load failed: $error');
      return const _HomeData(requestsLoaded: false);
    }

    String? fullName;

    try {
      final profile = await _client
          .from('customer_profiles')
          .select('full_name')
          .eq('id', customerId)
          .maybeSingle();

      fullName = profile?['full_name']?.toString().trim();
    } catch (error) {
      debugPrint('Home profile load failed: $error');
    }

    final activeRequests = <_HomeRequest>[];
    var requestsLoaded = true;

    try {
      final rows = await _client
          .from('booking_requests')
          .select('id, reference_code, goal, status, created_at, trainer_id')
          .eq('user_id', customerId)
          .eq('request_type', 'concierge_match')
          .order('created_at', ascending: false)
          .limit(20);

      for (final rawRow in rows) {
        final request = _HomeRequest.fromJson(Map<String, dynamic>.from(rawRow));

        if (!request.isClosed) {
          activeRequests.add(request);
        }
      }

      final trainerIds = activeRequests
          .map((request) => request.trainerId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      if (trainerIds.isNotEmpty) {
        try {
          final trainerRows = await _client
              .from('trainers')
              .select('id, full_name')
              .inFilter('id', trainerIds.toList());

          final namesById = <String, String>{};

          for (final trainerRow in trainerRows) {
            final id = trainerRow['id']?.toString().trim() ?? '';
            final name = trainerRow['full_name']?.toString().trim() ?? '';

            if (id.isNotEmpty && name.isNotEmpty) {
              namesById[id] = name;
            }
          }

          for (var index = 0; index < activeRequests.length; index++) {
            final request = activeRequests[index];
            final name = namesById[request.trainerId];

            if (name != null) {
              activeRequests[index] = request.copyWith(trainerName: name);
            }
          }
        } catch (error) {
          debugPrint('Home matched trainer load failed: $error');
        }
      }
    } catch (error) {
      requestsLoaded = false;
      debugPrint('Home request load failed: $error');
    }

    _HomeSession? nextSession;

    try {
      // A session stays "upcoming" until its hour is over, so one that is in
      // progress does not vanish from Home.
      final cutoffUtc = DateTime.now().toUtc().subtract(_sessionLength).toIso8601String();

      final rows = await _client
          .from('sessions')
          .select(
            'id, booking_request_id, trainer_id, scheduled_at, location_label, status, trainers(full_name)',
          )
          .eq('user_id', customerId)
          .inFilter('status', ['confirmed', 'booked'])
          .gte('scheduled_at', cutoffUtc)
          .order('scheduled_at', ascending: true)
          .limit(1);

      if (rows.isNotEmpty) {
        final session = _HomeSession.fromJson(Map<String, dynamic>.from(rows.first));

        if (session.isUpcoming(_sessionLength)) {
          nextSession = await _withReferenceCode(session);
        }
      }
    } catch (error) {
      debugPrint('Home session load failed: $error');
    }

    return _HomeData(
      fullName: fullName,
      activeRequests: activeRequests,
      requestsLoaded: requestsLoaded,
      nextSession: nextSession,
    );
  }

  Future<_HomeSession> _withReferenceCode(_HomeSession session) async {
    final requestId = session.bookingRequestId;

    if (requestId == null || requestId.isEmpty) return session;

    try {
      final row = await _client
          .from('booking_requests')
          .select('reference_code')
          .eq('id', requestId)
          .maybeSingle();

      final code = row?['reference_code']?.toString().trim() ?? '';

      return code.isEmpty ? session : session.copyWith(referenceCode: code);
    } catch (error) {
      debugPrint('Home session reference load failed: $error');
      return session;
    }
  }

  /// Opens a request or match screen and refreshes Home when the person comes
  /// back, so a request booked or closed there shows straight away.
  Future<void> _pushAndRefresh(String route, Object? extra) async {
    await context.push(route, extra: extra);
    if (!mounted) return;
    await _refreshHomeData();
  }

  // ---------------------------------------------------------------------------
  // SESSION CONFIRMATION PROMPT
  // ---------------------------------------------------------------------------

  Future<void> _maybeShowPendingSessionPrompt() async {
    if (_didCheckSessionPrompt || !mounted) return;

    _didCheckSessionPrompt = true;

    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final customerId = await CustomerIdentityService(client: _client).getCustomerId();

      final rows = await _client
          .from('sessions')
          .select('''
  id,
  booking_request_id,
  trainer_id,
  scheduled_at,
  location_label,
  customer_training_place,
  venue_choice,
  goal,
  notes,
  status,
  completion_prompt_shown_at,
  customer_outcome,
  trainers(
    full_name,
    profile_image_url,
    price_per_session
  )
''')
          .eq('user_id', customerId)
          .inFilter('status', ['confirmed', 'booked'])
          .order('scheduled_at', ascending: false);

      final nowUtc = DateTime.now().toUtc();

      Map<String, dynamic>? pendingSession;

      for (final rawRow in rows) {
        final session = Map<String, dynamic>.from(rawRow);

        final outcome = session['customer_outcome']?.toString().trim() ?? '';
        final shownAt = session['completion_prompt_shown_at']?.toString().trim() ?? '';
        final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

        if (scheduledAt == null || outcome.isNotEmpty || shownAt.isNotEmpty) {
          continue;
        }

        final sessionEndUtc = scheduledAt.toUtc().add(_sessionLength);
        final confirmationDeadline = sessionEndUtc.add(const Duration(hours: 24));

        if (!nowUtc.isBefore(sessionEndUtc) && nowUtc.isBefore(confirmationDeadline)) {
          pendingSession = session;
          break;
        }
      }

      if (!mounted || pendingSession == null) {
        return;
      }

      final sessionId = pendingSession['id']?.toString() ?? '';

      await _client.rpc(
        'mark_session_completion_prompt_shown',
        params: {'p_session_id': sessionId},
      );

      if (!mounted) return;

      await showSessionConfirmationFlow(
        context: context,
        session: pendingSession,
        onBookAgain: (session) async {
          await _startRepeatBookingFromHome(session);
        },
        onFinished: () async {
          await _refreshHomeData();
        },
      );
    } catch (error) {
      debugPrint('Home session confirmation check failed: $error');
    }
  }

  Future<void> _startRepeatBookingFromHome(Map<String, dynamic> session) async {
    final trainerId = session['trainer_id']?.toString().trim() ?? '';
    final bookingRequestId = session['booking_request_id']?.toString().trim() ?? '';

    if (trainerId.isEmpty) return;

    try {
      final trainers = await _trainerRepository.getTrainers();

      Trainer? selectedTrainer;

      for (final trainer in trainers) {
        if (trainer.id == trainerId) {
          selectedTrainer = trainer;
          break;
        }
      }

      if (!mounted || selectedTrainer == null) {
        return;
      }

      Map<String, dynamic>? previousBooking;

      if (bookingRequestId.isNotEmpty) {
        final row = await _client
            .from('booking_requests')
            .select('goal, message')
            .eq('id', bookingRequestId)
            .maybeSingle();

        if (row != null) {
          previousBooking = Map<String, dynamic>.from(row);
        }
      }

      if (!mounted) return;

      context.push(
        GSWRoutes.bookingRequest,
        extra: BookingRequestRouteData(
          trainer: selectedTrainer,
          initialGoal:
              session['goal']?.toString().trim() ?? previousBooking?['goal']?.toString().trim(),
          initialTrainingPlace: BookingRequestRouteData.trainingPlaceFromDb(
            session['customer_training_place'],
          ),
          initialVenueChoice: BookingRequestRouteData.venueChoiceFromDb(session['venue_choice']),
          initialLocationLabel: session['location_label']?.toString().trim(),
          initialNotes:
              session['notes']?.toString().trim() ?? previousBooking?['message']?.toString().trim(),
          isRepeatBooking: true,
        ),
      );
    } catch (error) {
      debugPrint('Home repeat booking failed: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // PRIORITY CARD (Open request, 998:3109)
  // The thing that needs a decision leads: a ready match first, then the next
  // session, then a request still being matched.
  // ---------------------------------------------------------------------------

  Widget? _buildPriorityCard(_HomeData data) {
    final matched = data.matchedRequest;

    if (matched != null) {
      final trainerName = matched.trainerName?.trim().isNotEmpty == true
          ? matched.trainerName!.trim()
          : 'Your trainer';

      return _OpenRequestCard(
        chipLabel: 'Recommendation ready',
        chipHighlighted: false,
        trailingLabel: matched.referenceCode,
        title: _goalHeadline(matched.goal),
        line: '$trainerName picked for you',
        ctaLabel: 'See your match',
        onTap: () => _pushAndRefresh(GSWRoutes.yourMatch, matched.id),
      );
    }

    final session = data.nextSession;

    if (session != null) {
      final start = GSWTime.toDubai(session.scheduledAt);

      return _OpenRequestCard(
        chipLabel: 'Next session',
        chipHighlighted: true,
        trailingLabel: session.referenceCode ?? GSWTime.relativeDay(start),
        title: '${GSWTime.dayLong(start)}, ${GSWTime.time(start)}',
        line: _sessionDescription(session),
        ctaLabel: 'View booking',
        onTap: () => _pushAndRefresh(GSWRoutes.sessionDetails, session.id),
      );
    }

    final inProgress = data.inProgressRequest;

    if (inProgress != null) {
      return _OpenRequestCard(
        chipLabel: 'Matching in progress',
        chipHighlighted: false,
        trailingLabel: inProgress.referenceCode,
        title: _goalHeadline(inProgress.goal),
        line: _matchingProgressMessage(inProgress),
        ctaLabel: 'See the request',
        onTap: () => _pushAndRefresh(GSWRoutes.conciergeRequestStatus, inProgress.id),
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // GREETING
  // ---------------------------------------------------------------------------

  Widget _buildGreeting(_HomeData data) {
    final name = _firstName(data.fullName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (name.isEmpty ? 'Hello' : 'Hello, $name').toUpperCase(),
          style: GSWTextStyles.displayLarge.copyWith(
            fontSize: 40,
            height: 44 / 40,
            color: GSWColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        // Dubai is the only live city, whatever the profile says.
        Text(
          'Dubai trainers, checked before they appear.',
          style: GSWTextStyles.bodyMedium.copyWith(
            color: GSWColors.textSecondary,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELP ME CHOOSE
  // ---------------------------------------------------------------------------

  Widget? _buildHelpMeChooseCard(_HomeData data) {
    // If we could not confirm whether a request is open, keep the entry point
    // hidden rather than risk a second request (one open request, DB rule).
    if (!data.requestsLoaded) return null;

    // 7.1: the recommendation card above already carries the request.
    if (data.matchedRequest != null) return null;

    final inProgress = data.inProgressRequest;

    if (inProgress != null) {
      return TrainerMatchingCard.requestOpen(
        onTap: () => _pushAndRefresh(GSWRoutes.conciergeRequestStatus, inProgress.id),
      );
    }

    return TrainerMatchingCard(onTap: () => context.push(GSWRoutes.helpMeChoose));
  }

  // ---------------------------------------------------------------------------
  // FEATURED TRAINERS
  // ---------------------------------------------------------------------------

  Widget _buildFeaturedTrainers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Featured trainers',
                style: GSWTextStyles.titleExtraSmall.copyWith(
                  color: GSWColors.textPrimary,
                  height: 1,
                ),
              ),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go(GSWRoutes.browseTrainers),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'See all',
                  style: GSWTextStyles.labelMedium.copyWith(
                    color: GSWColors.textAccent,
                    height: 20 / 14,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        FutureBuilder<List<Trainer>>(
          future: _featuredTrainersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: GSWColors.primary),
                ),
              );
            }

            if (snapshot.hasError) {
              debugPrint('Featured trainers load failed: ${snapshot.error}');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  Text(
                    'We could not load trainers. Pull down to try again, or browse them all.',
                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),

                  const SizedBox(height: 16),

                  GSWButton(
                    label: 'Browse trainers',
                    variant: GSWButtonVariant.secondary,
                    size: GSWButtonSize.medium,
                    onPressed: () => context.go(GSWRoutes.browseTrainers),
                  ),
                ],
              );
            }

            final featured = (snapshot.data ?? const <Trainer>[]).take(2).toList();

            if (featured.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Featured trainers will appear here soon. You can browse every trainer now.',
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),
              );
            }

            return Column(
              children: [
                for (int index = 0; index < featured.length; index++) ...[
                  const SizedBox(height: 8),
                  _buildFeaturedCard(featured[index]),
                  if (index != featured.length - 1) const SizedBox(height: 4),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(Trainer trainer) {
    return TrainerCard(
      name: trainer.fullName,
      service: trainer.primaryService ?? '',
      location: trainer.serviceArea?.trim().isNotEmpty == true ? trainer.serviceArea! : 'Dubai',
      price: trainer.pricePerSession,
      languages: trainer.languages,
      imageUrl: trainer.profileImageUrl,
      verificationChecks: trainer.verificationChecks,
      onTap: () => context.push(GSWRoutes.trainerProfile, extra: trainer),
    );
  }

  // ---------------------------------------------------------------------------
  // COPY HELPERS
  // ---------------------------------------------------------------------------

  String _firstName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';

    if (trimmed.isEmpty) return '';

    return trimmed.split(RegExp(r'\s+')).first;
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
      case '':
      case 'something else':
        return 'Your trainer match';
      default:
        return GSWPronoun.capitalise(normalized);
    }
  }

  /// "Sent yesterday at 9:12 AM. You will hear by tomorrow morning."
  /// A reply is due by the morning after the request was sent (Dubai time).
  String _matchingProgressMessage(_HomeRequest request) {
    final createdAt = request.createdAt;

    if (createdAt == null) {
      return 'Sent recently. You will hear from us by the next morning.';
    }

    final sent = GSWTime.toDubai(createdAt);
    final now = GSWTime.nowDubai();
    final yesterday = now.subtract(const Duration(days: 1));

    final String sentDay;

    if (GSWTime.isSameDay(sent, now)) {
      sentDay = 'today';
    } else if (GSWTime.isSameDay(sent, yesterday)) {
      sentDay = 'yesterday';
    } else {
      sentDay = 'on ${GSWTime.dayShort(sent)}';
    }

    final dueDay = sent.add(const Duration(days: 1));

    final String due;

    if (GSWTime.isSameDay(dueDay, now.add(const Duration(days: 1)))) {
      due = 'You will hear by tomorrow morning.';
    } else if (GSWTime.isSameDay(dueDay, now) && now.hour < 12) {
      due = 'You will hear by this morning.';
    } else {
      due = 'You will hear from us today.';
    }

    return 'Sent $sentDay at ${GSWTime.time(sent)}. $due';
  }

  String _sessionDescription(_HomeSession session) {
    final trainer = session.trainerName?.trim().isNotEmpty == true
        ? session.trainerName!.trim()
        : 'your trainer';

    final location = session.locationLabel?.trim() ?? '';

    return location.isEmpty ? 'With $trainer' : 'With $trainer, at $location';
  }
}

/// Figma "Open request" (998:3109 and the 7.x variants): Surface/Primary,
/// 1px accent border, radius 16, 16px padding, 10px gaps.
class _OpenRequestCard extends StatelessWidget {
  const _OpenRequestCard({
    required this.chipLabel,
    required this.chipHighlighted,
    required this.trailingLabel,
    required this.title,
    required this.line,
    required this.ctaLabel,
    required this.onTap,
  });

  final String chipLabel;
  final bool chipHighlighted;
  final String trailingLabel;
  final String title;
  final String line;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.borderFocused),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipHighlighted ? GSWColors.primary : GSWColors.surfaceInteractive,
                  borderRadius: BorderRadius.circular(GSWRadius.full),
                ),
                child: Text(
                  chipLabel,
                  style: GSWTextStyles.labelExtraSmall.copyWith(
                    color: chipHighlighted ? GSWColors.textInverse : GSWColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 12 / 11,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  trailingLabel,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSWTextStyles.bodyExtraSmall.copyWith(
                    color: GSWColors.textTertiary,
                    height: 12 / 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: GSWTextStyles.titleExtraSmall.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 22 / 18,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            line,
            style: GSWTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              color: GSWColors.textAccent,
              height: 18 / 13,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 36,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: GSWColors.primary,
                foregroundColor: GSWColors.textInverse,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GSWRadius.full),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                ctaLabel,
                style: GSWTextStyles.labelMedium.copyWith(
                  color: GSWColors.textInverse,
                  height: 16 / 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    this.fullName,
    this.activeRequests = const [],
    this.requestsLoaded = true,
    this.nextSession,
  });

  final String? fullName;
  final List<_HomeRequest> activeRequests;

  /// False when the request lookup failed, so Help me choose stays hidden.
  final bool requestsLoaded;

  final _HomeSession? nextSession;

  _HomeRequest? get matchedRequest {
    for (final request in activeRequests) {
      if (request.isMatched) return request;
    }

    return null;
  }

  _HomeRequest? get inProgressRequest {
    for (final request in activeRequests) {
      if (request.isInProgress) return request;
    }

    return null;
  }
}

class _HomeRequest {
  const _HomeRequest({
    required this.id,
    required this.referenceCode,
    required this.status,
    this.goal,
    this.createdAt,
    this.trainerId,
    this.trainerName,
  });

  final String id;
  final String referenceCode;
  final String status;
  final String? goal;
  final DateTime? createdAt;
  final String? trainerId;
  final String? trainerName;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isMatched => normalizedStatus == 'matched';

  bool get isClosed =>
      normalizedStatus == 'closed' ||
      normalizedStatus == 'cancelled' ||
      normalizedStatus == 'canceled' ||
      normalizedStatus == 'completed' ||
      normalizedStatus == 'confirmed' ||
      normalizedStatus == 'booked' ||
      normalizedStatus == 'lost';

  bool get isInProgress => normalizedStatus.isNotEmpty && !isMatched && !isClosed;

  _HomeRequest copyWith({String? trainerName}) {
    return _HomeRequest(
      id: id,
      referenceCode: referenceCode,
      status: status,
      goal: goal,
      createdAt: createdAt,
      trainerId: trainerId,
      trainerName: trainerName ?? this.trainerName,
    );
  }

  factory _HomeRequest.fromJson(Map<String, dynamic> json) {
    final reference = json['reference_code']?.toString().trim() ?? '';

    return _HomeRequest(
      id: json['id']?.toString().trim() ?? '',
      referenceCode: reference.isNotEmpty ? reference : 'Request',
      status: json['status']?.toString().trim() ?? '',
      goal: json['goal']?.toString().trim(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      trainerId: json['trainer_id']?.toString().trim(),
    );
  }
}

class _HomeSession {
  const _HomeSession({
    required this.id,
    required this.scheduledAt,
    this.bookingRequestId,
    this.trainerId,
    this.trainerName,
    this.locationLabel,
    this.referenceCode,
  });

  final String id;

  /// UTC instant of the session start.
  final DateTime scheduledAt;

  final String? bookingRequestId;
  final String? trainerId;
  final String? trainerName;
  final String? locationLabel;
  final String? referenceCode;

  /// True until the session's hour is over.
  bool isUpcoming(Duration length) {
    return !scheduledAt.toUtc().add(length).isBefore(DateTime.now().toUtc());
  }

  _HomeSession copyWith({String? referenceCode}) {
    return _HomeSession(
      id: id,
      scheduledAt: scheduledAt,
      bookingRequestId: bookingRequestId,
      trainerId: trainerId,
      trainerName: trainerName,
      locationLabel: locationLabel,
      referenceCode: referenceCode ?? this.referenceCode,
    );
  }

  factory _HomeSession.fromJson(Map<String, dynamic> json) {
    final trainer = json['trainers'];
    String? trainerName;

    if (trainer is Map) {
      trainerName = trainer['full_name']?.toString().trim();
    }

    // Supabase timestamptz always carries an offset; parse to a UTC instant.
    final parsed = DateTime.tryParse(json['scheduled_at']?.toString() ?? '');

    return _HomeSession(
      id: json['id']?.toString().trim() ?? '',
      scheduledAt: parsed?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      bookingRequestId: json['booking_request_id']?.toString().trim(),
      trainerId: json['trainer_id']?.toString().trim(),
      trainerName: trainerName,
      locationLabel: json['location_label']?.toString().trim(),
    );
  }
}
