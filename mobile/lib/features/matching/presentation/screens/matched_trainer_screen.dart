import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/matching/presentation/screens/nobody_fits_screen.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_request_detail_view.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_ui.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_row.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Figma 4.2 "Your match, within budget" (816:6109, note 816:6174) and
/// 4.3 "Your match, above budget" (816:6176, note 816:6241).
///
/// Opened from the request detail (Continue) and from the "We picked your
/// trainer" push. If the request is not showing a match (still matching,
/// nobody fits, booked without a trainer) it renders the matching screen for
/// that state instead of bouncing the navigation stack.
class MatchedTrainerScreen extends StatefulWidget {
  const MatchedTrainerScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<MatchedTrainerScreen> createState() => _MatchedTrainerScreenState();
}

enum _View { match, noFit, detail }

class _MatchedTrainerScreenState extends State<MatchedTrainerScreen> {
  late Future<_MatchData> _future;

  bool _isFindingWithinBudget = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MatchData> _load() async {
    final client = Supabase.instance.client;
    final customerId = await CustomerIdentityService(client: client).getCustomerId();

    final row = await client
        .from('booking_requests')
        .select('''
          id,
          status,
          trainer_id,
          goal,
          preferred_days,
          preferred_time,
          preferred_area,
          budget_min,
          budget_max,
          match_outcome,
          match_reason,
          matched_at,
          training_locations (
            name
          )
        ''')
        .eq('id', widget.requestId)
        .eq('user_id', customerId)
        .eq('request_type', 'concierge_match')
        .maybeSingle();

    if (row == null) {
      throw Exception('Request not found.');
    }

    final request = _MatchRequest.fromJson(Map<String, dynamic>.from(row));

    if (request.matchOutcome == 'no_fit') {
      return _MatchData(view: _View.noFit, request: request);
    }

    final hasTrainer = request.trainerId.isNotEmpty;
    final viewable =
        hasTrainer && (ConciergeStatus.isMatched(request.status) || ConciergeStatus.isClosed(request.status));

    if (!viewable) {
      return _MatchData(view: _View.detail, request: request);
    }

    final trainers = await TrainerRepository(client).getTrainers();

    Trainer? trainer;
    for (final candidate in trainers) {
      if (candidate.id == request.trainerId) {
        trainer = candidate;
        break;
      }
    }

    if (trainer == null) {
      // Trainer no longer listed: show the request record instead.
      return _MatchData(view: _View.detail, request: request);
    }

    return _MatchData(view: _View.match, request: request, trainer: trainer);
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _book(Trainer trainer) {
    context.push(
      GSWRoutes.bookingRequest,
      extra: BookingRequestRouteData(trainer: trainer, sourceConciergeRequestId: widget.requestId),
    );
  }

  void _viewProfile(Trainer trainer) {
    context.push(GSWRoutes.trainerProfile, extra: trainer);
  }

  Future<void> _notQuiteRight(String firstName, {String initialReason = 'days_times'}) async {
    final sent = await showConciergeSheet<bool>(
      context: context,
      builder: (_) => _RematchSheet(
        requestId: widget.requestId,
        firstName: firstName,
        initialReason: initialReason,
      ),
    );

    if (sent == true && mounted) {
      conciergeSafePop(context, true);
    }
  }

  /// 4.3 "Find someone within my budget": a real action, sends the request
  /// straight back to matching with the price as the reason.
  Future<void> _findWithinBudget(_MatchRequest request) async {
    if (_isFindingWithinBudget) return;

    setState(() {
      _isFindingWithinBudget = true;
    });

    try {
      final budget = ConciergeCopy.budgetRange(request.budgetMin, request.budgetMax);

      await Supabase.instance.client.rpc(
        'request_concierge_rematch',
        params: {
          'p_request_id': widget.requestId,
          'p_reason': 'price',
          'p_note': budget == null
              ? 'Find someone within my budget.'
              : 'Find someone within my budget of $budget.',
        },
      );

      if (!mounted) return;

      conciergeSafePop(context, true);
    } catch (error) {
      debugPrint('Find within budget failed: $error');

      if (!mounted) return;

      setState(() {
        _isFindingWithinBudget = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not update your request. Please try again.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MatchData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: GSWColors.backgroundPrimary,
            body: Center(child: CircularProgressIndicator(color: GSWColors.primary)),
          );
        }

        final data = snapshot.data;

        if (snapshot.hasError || data == null) {
          debugPrint('Matched trainer load failed: ${snapshot.error}');
          return _buildError();
        }

        return switch (data.view) {
          _View.noFit => NobodyFitsScreen(requestId: widget.requestId),
          _View.detail => ConciergeRequestDetailView(requestId: widget.requestId),
          _View.match => _buildMatch(data.request, data.trainer!),
        };
      },
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ConciergeBackButton(onTap: () => conciergeSafePop(context)),
              ),
              const Spacer(),
              Text(
                'We could not load your trainer',
                textAlign: TextAlign.center,
                style: GSWTextStyles.titleLarge.copyWith(
                  color: GSWColors.textPrimary,
                  height: 30 / 24,
                ),
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
                onPressed: _retry,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatch(_MatchRequest request, Trainer trainer) {
    final gender = trainer.gender;
    final firstName = trainer.fullName.trim().split(RegExp(r'\s+')).first;
    final price = trainer.pricePerSession;

    final budgetMax = request.budgetMax;
    final overBy = price != null && budgetMax != null && price > budgetMax ? price - budgetMax : null;
    final isAboveBudget = request.matchOutcome == 'outside_budget' || overBy != null;

    final isActive = ConciergeStatus.isMatched(request.status);
    final pickedOn = request.matchedAt;

    final area = request.area.isNotEmpty ? request.area : (trainer.serviceArea?.trim() ?? '');

    final whyLabel = isAboveBudget
        ? 'WHY WE PICKED ${GSWPronoun.object(gender).toUpperCase()}, AND WHAT IT COSTS'
        : 'WHY WE PICKED ${GSWPronoun.object(gender).toUpperCase()}';

    final whyText = request.matchReason.isNotEmpty
        ? request.matchReason
        : request.fallbackReason(firstName: firstName, gender: gender, aboveBudget: isAboveBudget);

    final bodyChildren = <Widget>[
      _NameAndPrice(
        firstName: firstName,
        subtitle: ['Personal training', if (area.isNotEmpty) area].join(' · '),
        price: price,
        alignTotalRight: !isAboveBudget,
      ),
      if (isAboveBudget && overBy != null) _AboveBudgetNote(overBy: overBy, request: request),
      _WhyCard(label: whyLabel, text: whyText),
      TrainerVerificationRow(
        onTap: () {
          TrainerVerificationSheet.show(
            context,
            trainerName: trainer.fullName,
            items: trainer.verificationChecks,
          );
        },
      ),
      if (pickedOn != null)
        Text(
          'Picked for you on ${GSWTime.dayLong(pickedOn).split(' ').skip(1).join(' ')}',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary, height: 16 / 12),
        ),
      if (!isActive)
        Text(
          ConciergeStatus.isBooked(request.status)
              ? 'This request became a session. You can still look at the trainer we picked.'
              : 'This request is closed. You can still look at the trainer we picked.',
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 16 / 12),
        ),
    ];

    final spaced = <Widget>[];
    for (var index = 0; index < bodyChildren.length; index++) {
      if (index > 0) spaced.add(const SizedBox(height: 24));
      spaced.add(bodyChildren[index]);
    }

    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(
                      name: trainer.fullName,
                      imagePath: trainer.profileImageUrl,
                      onBack: () => conciergeSafePop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: spaced,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _BottomBar(
            bookLabel: GSWPronoun.subject(gender) == 'they'
                ? 'Book a session with $firstName'
                : 'Book a session with ${GSWPronoun.object(gender)}',
            onBook: isActive ? () => _book(trainer) : null,
            showBook: isActive,
            alts: isAboveBudget && isActive
                ? _Alts.column([
                    _AltAction(
                      label: 'Find someone within my budget',
                      accent: true,
                      busy: _isFindingWithinBudget,
                      onTap: () => _findWithinBudget(request),
                    ),
                    _AltAction(
                      label: 'Not quite right?',
                      accent: false,
                      onTap: _isFindingWithinBudget ? null : () => _notQuiteRight(firstName),
                    ),
                  ])
                : _Alts.row([
                    _AltAction(
                      label: 'View full profile',
                      accent: true,
                      onTap: () => _viewProfile(trainer),
                    ),
                    if (isActive)
                      _AltAction(
                        label: 'Not quite right?',
                        accent: false,
                        onTap: () => _notQuiteRight(firstName),
                      ),
                  ]),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.imagePath, required this.onBack});

  final String name;
  final String? imagePath;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final url = conciergeTrainerImageUrl(imagePath);
    final topInset = MediaQuery.of(context).padding.top;

    final placeholder = Container(
      color: GSWColors.surfaceInteractive,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: topInset + 58),
      child: Opacity(
        opacity: 0.45,
        child: Text(
          conciergeInitials(name),
          style: GSWTextStyles.displayLarge.copyWith(
            color: GSWColors.textAccent,
            fontSize: 72,
            height: 76 / 72,
          ),
        ),
      ),
    );

    return SizedBox(
      height: 278 + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            placeholder
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 100 + topInset,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    GSWColors.backgroundPrimary.withValues(alpha: 0),
                    GSWColors.backgroundPrimary.withValues(alpha: 0.5),
                    GSWColors.backgroundPrimary,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: topInset + 24,
            child: ConciergeBackButton(onTap: onBack, overlay: true),
          ),
        ],
      ),
    );
  }
}

class _NameAndPrice extends StatelessWidget {
  const _NameAndPrice({
    required this.firstName,
    required this.subtitle,
    required this.price,
    required this.alignTotalRight,
  });

  final String firstName;
  final String subtitle;
  final double? price;
  final bool alignTotalRight;

  @override
  Widget build(BuildContext context) {
    final price = this.price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WE PICKED ${firstName.toUpperCase()}',
          style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary, height: 1),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),
        if (price != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    GSWMoney.aed(price),
                    style: GSWTextStyles.displaySmall.copyWith(
                      color: GSWColors.textAccent,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/session',
                    style: GSWTextStyles.bodySmall.copyWith(
                      color: GSWColors.textSecondary,
                      height: 16 / 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${GSWMoney.aed(GSWMoney.totalWithFee(price))} total, including the 5% service fee',
                  textAlign: alignTotalRight ? TextAlign.right : TextAlign.left,
                  style: GSWTextStyles.bodySmall.copyWith(
                    color: GSWColors.textSecondary,
                    height: 18 / 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AboveBudgetNote extends StatelessWidget {
  const _AboveBudgetNote({required this.overBy, required this.request});

  final double overBy;
  final _MatchRequest request;

  @override
  Widget build(BuildContext context) {
    final budget = ConciergeCopy.budgetRange(request.budgetMin, request.budgetMax);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Text(
        budget == null
            ? '${GSWMoney.aed(overBy)} above your stated budget.'
            : '${GSWMoney.aed(overBy)} above your stated budget of $budget.',
        style: GSWTextStyles.bodyMedium.copyWith(
          color: GSWColors.textAccent,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 19 / 13,
        ),
      ),
    );
  }
}

class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
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
          const SizedBox(height: 8),
          Text(
            text,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
          ),
        ],
      ),
    );
  }
}

class _AltAction {
  const _AltAction({required this.label, required this.accent, required this.onTap, this.busy = false});

  final String label;
  final bool accent;
  final VoidCallback? onTap;
  final bool busy;
}

class _Alts {
  const _Alts._(this.actions, this.stacked);

  factory _Alts.row(List<_AltAction> actions) => _Alts._(actions, false);
  factory _Alts.column(List<_AltAction> actions) => _Alts._(actions, true);

  final List<_AltAction> actions;
  final bool stacked;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.bookLabel,
    required this.onBook,
    required this.showBook,
    required this.alts,
  });

  final String bookLabel;
  final VoidCallback? onBook;
  final bool showBook;
  final _Alts alts;

  Widget _action(_AltAction action) {
    if (action.busy) {
      return const SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: GSWColors.primary),
          ),
        ),
      );
    }

    return ConciergeTextAction(label: action.label, accent: action.accent, onTap: action.onTap);
  }

  @override
  Widget build(BuildContext context) {
    final altWidgets = alts.actions.map(_action).toList();

    final Widget altsWidget;
    if (alts.stacked) {
      final children = <Widget>[];
      for (var index = 0; index < altWidgets.length; index++) {
        if (index > 0) children.add(const SizedBox(height: 10));
        children.add(altWidgets[index]);
      }
      altsWidget = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    } else {
      final children = <Widget>[];
      for (var index = 0; index < altWidgets.length; index++) {
        if (index > 0) children.add(const SizedBox(width: 24));
        children.add(altWidgets[index]);
      }
      altsWidget = Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
    }

    return Container(
      color: GSWColors.surfacePrimary,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBook) ...[
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.primary,
              label: bookLabel,
              onPressed: onBook,
            ),
            const SizedBox(height: 12),
          ],
          altsWidget,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// "Not quite right?" sheet
// -----------------------------------------------------------------------------

/// Owns its note controller so it is disposed only after the sheet has
/// finished animating out.
class _RematchSheet extends StatefulWidget {
  const _RematchSheet({
    required this.requestId,
    required this.firstName,
    required this.initialReason,
  });

  final String requestId;
  final String firstName;
  final String initialReason;

  @override
  State<_RematchSheet> createState() => _RematchSheetState();
}

class _RematchSheetState extends State<_RematchSheet> {
  static const List<MapEntry<String, String>> _reasons = [
    MapEntry('price', 'The price'),
    MapEntry('days_times', 'The days or times'),
    MapEntry('area', 'The area or place'),
    MapEntry('trainer', "I'd like a different trainer"),
    MapEntry('other', 'Something else'),
  ];

  final TextEditingController _noteController = TextEditingController();

  late String _reason;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason = widget.initialReason;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final note = _noteController.text.trim();

      await Supabase.instance.client.rpc(
        'request_concierge_rematch',
        params: {
          'p_request_id': widget.requestId,
          'p_reason': _reason,
          'p_note': note.isEmpty ? null : note,
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Request concierge rematch failed: $error');

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _error = error.toString().contains('MATCH_REQUEST_NOT_FOUND')
            ? 'This match has already changed. Go back to see the latest.'
            : 'We could not update your request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConciergeSheet(
      children: [
        const ConciergeSheetHeading(
          title: "What's not right?",
          intro: "Tell us and we'll keep looking. There's no obligation to book.",
        ),
        Container(
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
          ),
          child: Column(
            children: [
              for (var index = 0; index < _reasons.length; index++) ...[
                if (index > 0)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: GSWColors.surfaceInteractive,
                  ),
                _ReasonOption(
                  label: _reasons[index].value,
                  selected: _reason == _reasons[index].key,
                  onTap: _isSending
                      ? null
                      : () {
                          setState(() {
                            _reason = _reasons[index].key;
                            _error = null;
                          });
                        },
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anything to add? (optional)',
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              enabled: !_isSending,
              maxLines: 2,
              maxLength: 250,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'For example, evenings would suit me better',
                hintStyle: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                counterText: '',
                filled: true,
                fillColor: GSWColors.surfacePrimary,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GSWRadius.control),
                  borderSide: const BorderSide(color: GSWColors.borderSecondary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GSWRadius.control),
                  borderSide: const BorderSide(color: GSWColors.borderDisabled),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GSWRadius.control),
                  borderSide: const BorderSide(color: GSWColors.borderFocused),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Please don't include health details.",
              style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.error)),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.primary,
              label: 'Send and keep looking',
              isLoading: _isSending,
              onPressed: _isSending ? null : _send,
            ),
            const SizedBox(height: 20),
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.tertiary,
              label: 'Keep ${widget.firstName} as my match',
              onPressed: _isSending ? null : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: GSWColors.textPrimary,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GSWColors.primary : Colors.transparent,
                border: selected ? null : Border.all(color: GSWColors.borderSecondary, width: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

class _MatchData {
  const _MatchData({required this.view, required this.request, this.trainer});

  final _View view;
  final _MatchRequest request;
  final Trainer? trainer;
}

class _MatchRequest {
  const _MatchRequest({
    required this.status,
    required this.trainerId,
    required this.goal,
    required this.days,
    required this.time,
    required this.area,
    required this.locationName,
    required this.budgetMin,
    required this.budgetMax,
    required this.matchOutcome,
    required this.matchReason,
    required this.matchedAt,
  });

  factory _MatchRequest.fromJson(Map<String, dynamic> json) {
    final location = json['training_locations'];

    return _MatchRequest(
      status: ConciergeStatus.normalise(json['status']),
      trainerId: json['trainer_id']?.toString().trim() ?? '',
      goal: json['goal']?.toString().trim() ?? '',
      days: ConciergeCopy.days(json['preferred_days']),
      time: json['preferred_time']?.toString().trim() ?? '',
      area: json['preferred_area']?.toString().trim() ?? '',
      locationName: location is Map ? location['name']?.toString().trim() : null,
      budgetMin: GSWMoney.parse(json['budget_min']),
      budgetMax: GSWMoney.parse(json['budget_max']),
      matchOutcome: ConciergeStatus.normalise(json['match_outcome']),
      matchReason: json['match_reason']?.toString().trim() ?? '',
      matchedAt: GSWTime.parseToDubai(json['matched_at']),
    );
  }

  final String status;
  final String trainerId;
  final String goal;
  final List<String> days;
  final String time;
  final String area;
  final String? locationName;
  final double? budgetMin;
  final double? budgetMax;
  final String matchOutcome;
  final String matchReason;
  final DateTime? matchedAt;

  /// Used only when the matcher left no reason. Built from what the customer
  /// asked for, including where they want to train (gym, home or outdoors).
  String fallbackReason({
    required String firstName,
    required Object? gender,
    required bool aboveBudget,
  }) {
    final headline = ConciergeCopy.goalHeadline(goal);
    final goalText = headline.isEmpty || headline == 'Your training goal'
        ? 'You want help with your training'
        : 'You want to ${headline[0].toLowerCase()}${headline.substring(1)}';

    final schedule = ConciergeCopy.daysAndTimePhrase(days, time);
    final place = ConciergeCopy.placePhrase(locationName, area);

    final asked = [
      goalText,
      if (schedule.isNotEmpty) 'on $schedule',
      if (place.isNotEmpty) place,
    ].join(', ');

    final pronoun = GSWPronoun.subject(gender);
    final works = pronoun == 'they' ? 'work' : 'works';

    if (aboveBudget) {
      final budget = ConciergeCopy.budgetRange(budgetMin, budgetMax);
      final inside = budget == null ? 'inside your budget' : 'inside $budget';

      return 'Nobody $inside has the times and place you asked for right now. '
          '$firstName does, and $pronoun $works with the same goal. '
          'If the price does not work, we will keep looking.';
    }

    return '$asked. We think $firstName is the right fit for that.';
  }
}
