import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Your trainer request" detail for a Help me choose request.
///
/// One record, four named states (Figma note 819:3021):
/// - Request submitted / Matching in progress: 9.2b (1174:3781). Timeline,
///   what you asked for, note. Cancelling is the only action.
/// - Recommendation ready: 9.2 (819:2959). Asked for, note, trainer card,
///   Continue and "Cancel this request".
/// - Session booked: 9.4 (819:3044). Trainer card says the request became a
///   session, "View the booking", and "This request is closed".
/// - Cancelled: read-only, closed.
class ConciergeRequestDetailView extends StatefulWidget {
  const ConciergeRequestDetailView({super.key, required this.requestId});

  final String requestId;

  @override
  State<ConciergeRequestDetailView> createState() => _ConciergeRequestDetailViewState();
}

class _ConciergeRequestDetailViewState extends State<ConciergeRequestDetailView> {
  late Future<ConciergeRequestDetail> _future;

  bool _isCancelling = false;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _future = ConciergeRequestDetail.load(widget.requestId);
  }

  Future<void> _refresh() async {
    final future = ConciergeRequestDetail.load(widget.requestId);

    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error state.
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _continue(ConciergeRequestDetail request) async {
    if (_isOpening) return;
    _isOpening = true;

    try {
      if (request.matchOutcome == 'no_fit') {
        await context.push(GSWRoutes.matchNoFit, extra: request.id);
      } else {
        await context.push<bool>(GSWRoutes.matchedTrainer, extra: request.id);
      }

      // A rematch or an update moves the request back to matching.
      if (mounted) await _refresh();
    } finally {
      _isOpening = false;
    }
  }

  Future<void> _viewBooking(ConciergeRequestDetail request) async {
    if (_isOpening) return;
    _isOpening = true;

    try {
      final sessionId = request.sessionId;

      if (sessionId != null && sessionId.isNotEmpty) {
        await context.push(GSWRoutes.sessionDetails, extra: sessionId);
      } else {
        // Upcoming tab of Sessions.
        await context.push(GSWRoutes.sessions, extra: 1);
      }
    } finally {
      _isOpening = false;
    }
  }

  Future<void> _cancel(ConciergeRequestDetail request) async {
    if (_isCancelling || !request.canCancel) return;

    final confirmed = await showConciergeSheet<bool>(
      context: context,
      builder: (sheetContext) => _CancelRequestSheet(isMatched: request.isMatched),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final client = Supabase.instance.client;
      final customerId = await CustomerIdentityService(client: client).getCustomerId();

      final updated = await client
          .from('booking_requests')
          .update({'status': 'cancelled'})
          .eq('id', request.id)
          .eq('user_id', customerId)
          .eq('request_type', 'concierge_match')
          .select('id');

      if (updated.isEmpty) {
        throw Exception('Cancel matched no rows.');
      }

      if (!mounted) return;

      conciergeSafePop(context, true);
    } catch (error) {
      debugPrint('Cancel concierge request failed: $error');

      if (!mounted) return;

      setState(() {
        _isCancelling = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not cancel the request. Please try again.')),
      );
    }
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
        child: FutureBuilder<ConciergeRequestDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              debugPrint('Concierge request load failed: ${snapshot.error}');
              return _buildError();
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConciergeBackButton(onTap: () => conciergeSafePop(context)),
          ),
          const Spacer(),
          Text(
            'We could not load this request',
            textAlign: TextAlign.center,
            style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 24),
          GSWButton(
            size: GSWButtonSize.large,
            variant: GSWButtonVariant.secondary,
            label: 'Try again',
            onPressed: _refresh,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildContent(ConciergeRequestDetail request) {
    final children = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: ConciergeBackButton(onTap: () => conciergeSafePop(context)),
      ),
      _TitleBlock(reference: request.referenceCode, status: ConciergeStatus.label(request.status)),
      if (request.isInProgress) _StatusTimeline(request: request),
      _AskedCard(request: request),
      if (request.note.isNotEmpty) _NoteCard(note: request.note),
      if (request.trainerName != null && !request.isInProgress)
        _TrainerCard(
          label: request.isBooked ? 'THIS REQUEST BECAME A SESSION' : 'WE PICKED YOUR TRAINER',
          name: request.trainerName!,
          imagePath: request.trainerImage,
          subtitle: request.trainerSubtitle,
        ),
    ];

    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) spaced.add(const SizedBox(height: 24));
      spaced.add(children[index]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            color: GSWColors.primary,
            backgroundColor: GSWColors.surfacePrimary,
            onRefresh: _refresh,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced),
              ),
            ),
          ),
        ),
        _buildBottomBar(request),
      ],
    );
  }

  Widget _buildBottomBar(ConciergeRequestDetail request) {
    final children = <Widget>[];

    if (request.isInProgress) {
      // 9.2b: cancelling is the only action.
      children.add(
        GSWButton(
          size: GSWButtonSize.large,
          variant: GSWButtonVariant.secondary,
          label: 'Cancel this request',
          isLoading: _isCancelling,
          onPressed: _isCancelling ? null : () => _cancel(request),
        ),
      );
    } else if (request.isMatched) {
      // 9.2: Continue, then the muted cancel link.
      children.addAll([
        GSWButton(
          size: GSWButtonSize.large,
          variant: GSWButtonVariant.primary,
          label: 'Continue',
          onPressed: _isCancelling ? null : () => _continue(request),
        ),
        const SizedBox(height: 12),
        _isCancelling
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: GSWColors.primary),
                ),
              )
            : ConciergeTextAction(
                label: 'Cancel this request',
                accent: false,
                onTap: () => _cancel(request),
              ),
      ]);
    } else {
      // 9.4 booked, or cancelled.
      if (request.isBooked) {
        children.addAll([
          GSWButton(
            size: GSWButtonSize.large,
            variant: GSWButtonVariant.primary,
            label: 'View the booking',
            onPressed: () => _viewBooking(request),
          ),
          const SizedBox(height: 12),
        ]);
      }
      children.add(
        Text(
          'This request is closed',
          textAlign: TextAlign.center,
          style: GSWTextStyles.bodyMedium.copyWith(
            color: GSWColors.textSecondary,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.reference, required this.status});

  final String reference;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your trainer request',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 1),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (reference.isNotEmpty) ...[
              Text(
                reference,
                style: GSWTextStyles.labelMedium.copyWith(
                  color: GSWColors.textSecondary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
            ],
            ConciergeStatusChip(label: status),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.highlighted = false});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: highlighted ? Border.all(color: GSWColors.borderFocused) : null,
      ),
      child: child,
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.request});

  final ConciergeRequestDetail request;

  @override
  Widget build(BuildContext context) {
    final lookingAgain = request.rematchRequestedAt != null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Where it's up to",
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary, height: 1),
          ),
          const SizedBox(height: 14),
          _TimelineStep(
            state: _StepState.done,
            title: 'Request sent',
            subtitle: ConciergeCopy.sentAt(request.createdAt),
          ),
          _TimelineStep(
            state: _StepState.now,
            title: lookingAgain ? 'We are looking again' : 'A person is matching you',
            subtitle: lookingAgain
                ? 'We read what you told us and check who else fits and is free.'
                : 'We read every request ourselves and check who fits and is free.',
          ),
          _TimelineStep(
            state: _StepState.next,
            title: 'Your recommendation',
            subtitle: ConciergeCopy.recommendationPromise(
              request.rematchRequestedAt ?? request.createdAt,
            ),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, now, next }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.state,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final _StepState state;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isNext = state == _StepState.next;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                _dot(),
                if (!isLast) ...[
                  const SizedBox(height: 4),
                  Expanded(child: Container(width: 2, color: GSWColors.surfaceInteractive)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GSWTextStyles.labelMedium.copyWith(
                      color: isNext ? GSWColors.textSecondary : GSWColors.textPrimary,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: GSWColors.textSecondary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    switch (state) {
      case _StepState.done:
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: GSWColors.primary),
        );
      case _StepState.now:
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.primary, width: 2),
          ),
        );
      case _StepState.next:
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.textSecondary, width: 2),
          ),
        );
    }
  }
}

class _AskedCard extends StatelessWidget {
  const _AskedCard({required this.request});

  final ConciergeRequestDetail request;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Goal', ConciergeCopy.goalHeadline(request.goal)),
      MapEntry('Days', ConciergeCopy.daysShortList(request.days)),
      MapEntry('Time', ConciergeCopy.capitalise(request.time)),
      MapEntry('Where', request.whereLabel),
      MapEntry('Trainer', request.trainerAndBudgetLabel),
      MapEntry(
        'Language',
        request.language.isEmpty ? 'No preference' : ConciergeCopy.capitalise(request.language),
      ),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you asked for',
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary, height: 1),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: GSWColors.surfaceInteractive),
          for (final row in rows) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.key,
                  style: GSWTextStyles.bodyMedium.copyWith(
                    color: GSWColors.textSecondary,
                    height: 20 / 14,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? 'Not specified' : row.value,
                    textAlign: TextAlign.right,
                    style: GSWTextStyles.labelMedium.copyWith(
                      color: GSWColors.textPrimary,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your note',
            style: GSWTextStyles.labelMedium.copyWith(
              color: GSWColors.textSecondary,
              height: 18 / 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
          ),
        ],
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({
    required this.label,
    required this.name,
    required this.imagePath,
    required this.subtitle,
  });

  final String label;
  final String name;
  final String? imagePath;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GSWTextStyles.bodyExtraSmall.copyWith(
              color: GSWColors.textAccent,
              fontWeight: FontWeight.w500,
              height: 12 / 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ConciergeTrainerAvatar(name: name, imagePath: imagePath, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GSWTextStyles.bodyLarge.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 22 / 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: GSWColors.textSecondary,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelRequestSheet extends StatelessWidget {
  const _CancelRequestSheet({required this.isMatched});

  final bool isMatched;

  @override
  Widget build(BuildContext context) {
    return ConciergeSheet(
      children: [
        ConciergeSheetHeading(
          title: 'Cancel this request?',
          intro: isMatched
              ? 'This removes the recommendation and closes the request. '
                    'You can start a new one afterwards.'
              : 'We will stop matching this request. You can start a new one afterwards.',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.primary,
              label: 'Cancel request',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 20),
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.tertiary,
              label: 'Keep request',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

class ConciergeRequestDetail {
  const ConciergeRequestDetail({
    required this.id,
    required this.referenceCode,
    required this.status,
    required this.goal,
    required this.days,
    required this.time,
    required this.area,
    required this.locationName,
    required this.genderPreference,
    required this.budgetMin,
    required this.budgetMax,
    required this.language,
    required this.note,
    required this.createdAt,
    required this.rematchRequestedAt,
    required this.matchOutcome,
    required this.trainerName,
    required this.trainerImage,
    required this.trainerServiceArea,
    required this.trainerPrice,
    required this.sessionId,
    required this.sessionRate,
  });

  final String id;
  final String referenceCode;
  final String status;
  final String goal;
  final List<String> days;
  final String time;
  final String area;
  final String? locationName;
  final String genderPreference;
  final double? budgetMin;
  final double? budgetMax;
  final String language;
  final String note;
  final DateTime? createdAt;
  final DateTime? rematchRequestedAt;
  final String matchOutcome;

  final String? trainerName;
  final String? trainerImage;
  final String? trainerServiceArea;
  final double? trainerPrice;

  final String? sessionId;
  final double? sessionRate;

  bool get isMatched => ConciergeStatus.isMatched(status);
  bool get isBooked => ConciergeStatus.isBooked(status);
  bool get isClosed => ConciergeStatus.isClosed(status);
  bool get isInProgress => !isMatched && !isClosed;
  bool get canCancel => !isClosed;

  String get whereLabel => [
    if (locationName != null && locationName!.isNotEmpty) ConciergeCopy.placeLabel(locationName),
    if (area.isNotEmpty) area,
  ].join(', ');

  String get trainerAndBudgetLabel {
    final preference = genderPreference.isEmpty
        ? 'No preference'
        : ConciergeCopy.capitalise(genderPreference);
    final budget = ConciergeCopy.budgetRange(budgetMin, budgetMax);

    return budget == null ? preference : '$preference, $budget';
  }

  /// "Personal training · Dubai Marina · AED 250". A booked request shows the
  /// rate that was charged (session snapshot), otherwise the trainer's rate.
  String get trainerSubtitle {
    final place = (trainerServiceArea?.trim().isNotEmpty ?? false) ? trainerServiceArea!.trim() : area;
    final price = isBooked ? (sessionRate ?? trainerPrice) : trainerPrice;

    return [
      'Personal training',
      if (place.isNotEmpty) place,
      if (price != null) GSWMoney.aed(price),
    ].join(' · ');
  }

  static Future<ConciergeRequestDetail> load(String requestId) async {
    final client = Supabase.instance.client;
    final customerId = await CustomerIdentityService(client: client).getCustomerId();

    final row = await client
        .from('booking_requests')
        .select('''
          id,
          reference_code,
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
          created_at,
          rematch_requested_at,
          match_outcome,
          trainer_id,
          training_locations (
            name
          ),
          trainers!booking_requests_trainer_id_fkey (
            full_name,
            profile_image_url,
            service_area,
            price_per_session
          )
        ''')
        .eq('id', requestId)
        .eq('user_id', customerId)
        .eq('request_type', 'concierge_match')
        .maybeSingle();

    if (row == null) {
      throw Exception('Request not found.');
    }

    final json = Map<String, dynamic>.from(row);
    final status = ConciergeStatus.normalise(json['status']);

    final location = json['training_locations'];
    final trainer = json['trainers'];

    String? sessionId;
    double? sessionRate;

    if (ConciergeStatus.isBooked(status)) {
      try {
        final linked = await client
            .from('booking_requests')
            .select('id')
            .eq('source_concierge_request_id', requestId)
            .eq('user_id', customerId);

        final linkedIds = linked
            .map((item) => item['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        // Booking from a match updates the concierge request itself, so its
        // own id is the usual link; separate linked requests are also checked.
        linkedIds.insert(0, requestId);

        if (linkedIds.isNotEmpty) {
          // `*` so a database without session_rate yet still answers.
          final sessions = await client
              .from('sessions')
              .select('*')
              .inFilter('booking_request_id', linkedIds)
              .eq('user_id', customerId)
              .order('scheduled_at', ascending: false)
              .limit(1);

          if (sessions.isNotEmpty) {
            sessionId = sessions.first['id']?.toString();
            sessionRate = GSWMoney.parse(sessions.first['session_rate']);
          }
        }
      } catch (error) {
        debugPrint('Linked session lookup failed: $error');
      }
    }

    final trainerName = trainer is Map ? trainer['full_name']?.toString().trim() : null;

    return ConciergeRequestDetail(
      id: json['id']?.toString().trim() ?? requestId,
      referenceCode: json['reference_code']?.toString().trim() ?? '',
      status: status,
      goal: json['goal']?.toString().trim() ?? '',
      days: ConciergeCopy.days(json['preferred_days']),
      time: json['preferred_time']?.toString().trim() ?? '',
      area: json['preferred_area']?.toString().trim() ?? '',
      locationName: location is Map ? location['name']?.toString().trim() : null,
      genderPreference: json['trainer_gender_preference']?.toString().trim() ?? '',
      budgetMin: GSWMoney.parse(json['budget_min']),
      budgetMax: GSWMoney.parse(json['budget_max']),
      language: json['language_preference']?.toString().trim() ?? '',
      note: json['message']?.toString().trim() ?? '',
      createdAt: GSWTime.parseToDubai(json['created_at']),
      rematchRequestedAt: GSWTime.parseToDubai(json['rematch_requested_at']),
      matchOutcome: ConciergeStatus.normalise(json['match_outcome']),
      trainerName: trainerName == null || trainerName.isEmpty ? null : trainerName,
      trainerImage: trainer is Map ? trainer['profile_image_url']?.toString() : null,
      trainerServiceArea: trainer is Map ? trainer['service_area']?.toString() : null,
      trainerPrice: trainer is Map ? GSWMoney.parse(trainer['price_per_session']) : null,
      sessionId: sessionId,
      sessionRate: sessionRate,
    );
  }
}
