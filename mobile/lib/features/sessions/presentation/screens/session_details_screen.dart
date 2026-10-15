import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:mobile/features/sessions/presentation/screens/session_confirmation_flow.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 10.1 Booking detail. Also shows the cancelled, completed, reported and
/// awaiting-confirmation states of the same booking.
class SessionDetailsScreen extends StatefulWidget {
  const SessionDetailsScreen({super.key, required this.sessionId, this.openFeedback = false});

  final String sessionId;

  final bool openFeedback;

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  late final SessionsService _service = SessionsService(_client);

  late Future<Map<String, dynamic>> _sessionFuture;

  bool _feedbackPromptScheduled = false;

  /// Guards Move, Cancel, View profile and the feedback flow against double taps.
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _service.getSession(widget.sessionId);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final future = _service.getSession(widget.sessionId);
    setState(() => _sessionFuture = future);
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error state.
    }
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(GSWRoutes.sessions);
  }

  Future<void> _move() => _guarded(() async {
        await context.push<bool>(GSWRoutes.moveSession, extra: widget.sessionId);
        await _reload();
      });

  Future<void> _cancel() => _guarded(() async {
        await context.push<bool>(GSWRoutes.cancelSession, extra: widget.sessionId);
        await _reload();
      });

  Future<void> _openTrainer(Map<String, dynamic> session) => _guarded(() async {
        final trainerId = session['trainer_id']?.toString().trim() ?? '';
        Trainer? trainer;
        try {
          final trainers = await TrainerRepository(_client).getTrainers();
          for (final item in trainers) {
            if (item.id == trainerId) {
              trainer = item;
              break;
            }
          }
        } catch (error) {
          debugPrint('Trainer load failed: $error');
        }

        if (!mounted) return;

        if (trainer == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("We couldn't open this trainer's profile.")),
          );
          return;
        }

        await context.push(GSWRoutes.trainerProfile, extra: trainer);
      });

  Future<void> _openFeedback(Map<String, dynamic> session) => _guarded(() async {
        try {
          await _client.rpc(
            'mark_session_completion_prompt_shown',
            params: {'p_session_id': widget.sessionId},
          );
        } catch (error) {
          debugPrint('mark_session_completion_prompt_shown failed: $error');
        }

        if (!mounted) return;

        await showSessionConfirmationFlow(
          context: context,
          session: session,
          onBookAgain: _startRepeatBooking,
          onFinished: _reload,
        );
      });

  /// Same repeat booking as the Sessions tab: reopen this trainer's booking
  /// request prefilled from the session.
  Future<void> _startRepeatBooking(Map<String, dynamic> session) async {
    final trainerId = session['trainer_id']?.toString().trim() ?? '';
    if (trainerId.isEmpty) {
      _showRepeatBookingError();
      return;
    }

    try {
      final trainers = await TrainerRepository(_client).getTrainers();

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

      await context.push(
        GSWRoutes.bookingRequest,
        extra: BookingRequestRouteData(
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
        const SnackBar(
          content: Text("We could not open this trainer's availability. Please try again."),
        ),
      );
  }

  void _showReceiptPending() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your receipt will be available here once card payments are live.'),
      ),
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
        child: FutureBuilder<Map<String, dynamic>>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              debugPrint('Session details load failed: ${snapshot.error}');
              return _buildErrorState();
            }

            final session = snapshot.data!;

            if (widget.openFeedback && !_feedbackPromptScheduled && sessionNeedsConfirmation(session)) {
              _feedbackPromptScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openFeedback(session);
              });
            }

            return _buildContent(session);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> session) {
    final start = sessionStartDubai(session);
    if (start == null) return _buildErrorState();

    final view = _DetailView(session, start);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SessionBackButton(onTap: _goBack),
                const SizedBox(height: 24),
                Text(
                  'Your session',
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (view.referenceCode != null) ...[
                      Text(
                        view.referenceCode!,
                        style: GSWTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w500,
                          color: GSWColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    _StatusChip(label: view.statusLabel, muted: view.isCancelled),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTrainerCard(session, view.trainer),
                const SizedBox(height: 24),
                _buildDetailCard(session, view),
                const SizedBox(height: 24),
                if (view.isCancelled)
                  _buildCancelledCard(session, view)
                else
                  _buildPaymentCard(session, view),
                if (view.policyHint != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    view.policyHint!,
                    textAlign: TextAlign.center,
                    style: GSWTextStyles.bodySmall.copyWith(
                      color: GSWColors.textTertiary,
                      height: 16 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (view.canManage) _buildManageBar(view),
        if (view.awaitingAnswer) _buildFeedbackBar(session),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: child,
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> session, SessionTrainerInfo trainer) {
    return _card(
      child: Row(
        children: [
          SessionTrainerAvatar(name: trainer.name, imagePath: trainer.imagePath, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    height: 22 / 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trainer.serviceLabel,
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
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: GSWButton(
              label: 'View profile',
              onPressed: _isBusy ? null : () => _openTrainer(session),
              variant: GSWButtonVariant.secondary,
              size: GSWButtonSize.medium,
              fullWidth: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(Map<String, dynamic> session, _DetailView view) {
    final location = session['location_label']?.toString().trim() ?? '';
    final goal = view.goal;
    final note = view.note;

    final rows = <Widget>[
      _kv('When', '${GSWTime.dayShort(view.start)}, ${GSWTime.timeRange(view.start, kSessionLength)}'),
      _kv('Where', location.isEmpty ? 'Confirmed with your trainer' : location),
      if (goal != null) _kv('Goal', goal),
      if (note != null) _kv('Note', note),
    ];

    return _card(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            rows[index],
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool highlighted = false, bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GSWTextStyles.bodyMedium.copyWith(height: 20 / 14, color: GSWColors.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GSWTextStyles.labelMedium.copyWith(
              height: 20 / 14,
              color: highlighted ? GSWColors.textAccent : GSWColors.textPrimary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> session, _DetailView view) {
    final amounts = view.amounts;
    final paidOn = GSWTime.parseToDubai(session['created_at']);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: GSWTextStyles.labelLarge.copyWith(
              color: GSWColors.textPrimary,
              height: 20 / 16,
            ),
          ),
          const SizedBox(height: 10),
          _kv('Session, 60 minutes', _fixed(amounts.sessionRate)),
          const SizedBox(height: 10),
          _kv('Service fee (5%)', _fixed(amounts.serviceFee)),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
          const SizedBox(height: 10),
          _kv('Total paid', _fixed(amounts.total), highlighted: true),
          if (paidOn != null) ...[
            const SizedBox(height: 10),
            Text(
              'Paid ${GSWTime.dayLong(paidOn).split(' ').skip(1).join(' ')} by card',
              style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: _showReceiptPending,
            child: Text(
              'View receipt',
              style: GSWTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                height: 18 / 13,
                color: GSWColors.textAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cancelled state: shows the refund stored when the session was cancelled
  /// and the amounts actually paid, never a figure recomputed from today.
  Widget _buildCancelledCard(Map<String, dynamic> session, _DetailView view) {
    final refund = GSWMoney.parse(session['cancellation_refund_amount']);
    final cancelledAt = GSWTime.parseToDubai(session['cancelled_at']);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancelled',
            style: GSWTextStyles.labelLarge.copyWith(
              color: GSWColors.textPrimary,
              height: 20 / 16,
            ),
          ),
          const SizedBox(height: 10),
          _kv('Total paid', _fixed(view.amounts.total)),
          const SizedBox(height: 10),
          _kv('Refunded', refund == null ? 'Being confirmed' : _fixed(refund), highlighted: true),
          const SizedBox(height: 10),
          Text(
            [
              if (cancelledAt != null) 'Cancelled ${GSWTime.dayAndTime(cancelledAt)}.',
              'Refunds reach the card you paid with in 5 to 10 working days.',
            ].join(' '),
            style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showReceiptPending,
            child: Text(
              'View receipt',
              style: GSWTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                height: 18 / 13,
                color: GSWColors.textAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom bar 819:3167: 16 top, 28 bottom, 12 gap; Move above a full-width
  /// Medium 14 secondary "Cancel booking" line (note 819:3174).
  Widget _buildManageBar(_DetailView view) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GSWButton(
            label: 'Move this session',
            onPressed: _isBusy ? null : _move,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isBusy ? null : _cancel,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                'Cancel booking',
                textAlign: TextAlign.center,
                style: GSWTextStyles.bodyMedium.copyWith(
                  height: 20 / 14,
                  color: GSWColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBar(Map<String, dynamic> session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: GSWButton(
        label: 'Tell us if it took place',
        onPressed: _isBusy ? null : () => _openFeedback(session),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SessionBackButton(onTap: _goBack),
          const Spacer(),
          Text(
            "We couldn't load this session",
            style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const Spacer(),
          GSWButton(label: 'Try again', onPressed: _reload),
          const SizedBox(height: 8),
          GSWButton(
            label: 'Back to my sessions',
            variant: GSWButtonVariant.tertiary,
            onPressed: () => context.go(GSWRoutes.sessions),
          ),
        ],
      ),
    );
  }

  /// Payment card amounts are shown with two decimals, as in Figma.
  String _fixed(double? value) => value == null ? '–' : 'AED ${value.toStringAsFixed(2)}';
}

// =============================================================================
// View model
// =============================================================================

class _DetailView {
  _DetailView(this.session, this.start)
      : trainer = SessionTrainerInfo.fromSession(session),
        amounts = SessionAmounts.fromSession(session);

  final Map<String, dynamic> session;
  final DateTime start;
  final SessionTrainerInfo trainer;
  final SessionAmounts amounts;

  Map<String, dynamic> get _request {
    final value = session['booking_requests'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  String? get referenceCode {
    final value = _request['reference_code']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? _firstText(Object? a, Object? b) {
    final first = a?.toString().trim() ?? '';
    if (first.isNotEmpty) return first;
    final second = b?.toString().trim() ?? '';
    return second.isEmpty ? null : second;
  }

  String? get goal {
    final value = _firstText(session['goal'], _request['goal']);
    return value == null ? null : GSWPronoun.capitalise(value.replaceAll('_', ' '));
  }

  String? get note => _firstText(session['notes'], _request['message']);

  String get status => sessionStatus(session);

  bool get isCancelled => sessionIsCancelled(session);

  bool get isActive => kActiveSessionStatuses.contains(status);

  DateTime get _now => GSWTime.nowDubai();

  bool get hasStarted => !start.isAfter(_now);

  bool get hasEnded => !start.add(kSessionLength).isAfter(_now);

  /// Move and Cancel are offered only for a booked session that has not started.
  bool get canManage => isActive && !hasStarted;

  bool get awaitingAnswer => sessionNeedsConfirmation(session);

  String get statusLabel {
    if (isCancelled) return 'Cancelled';
    if (status == 'reported') return 'Reported';
    if (status == 'completed') return 'Completed';
    if (isActive && hasEnded) return 'Awaiting confirmation';
    if (isActive && hasStarted) return 'Happening now';
    return 'Confirmed';
  }

  /// The line under the payment card for a booking that can still be cancelled.
  String? get policyHint {
    if (!canManage) return null;

    final remaining = start.difference(_now);

    if (remaining >= const Duration(hours: 24)) {
      final cutoff = start.subtract(const Duration(hours: 24));
      return amounts.sessionRate == null
          ? 'Cancel before ${GSWTime.dayAndTime(cutoff)} to get the full session fee back'
          : 'Cancel before ${GSWTime.dayAndTime(cutoff)} to get the full ${GSWMoney.aed(amounts.sessionRate)} session fee back';
    }

    return amounts.halfRate == null
        ? 'Inside 24 hours: cancelling now returns half the session fee'
        : 'Inside 24 hours: cancelling now returns ${GSWMoney.aed(amounts.halfRate)}, half the session fee';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: muted ? GSWColors.surfacePrimary : GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(GSWRadius.full),
      ),
      child: Text(
        label,
        style: GSWTextStyles.bodySmall.copyWith(
          height: 14 / 12,
          fontWeight: FontWeight.w500,
          color: muted ? GSWColors.textSecondary : GSWColors.textPrimary,
        ),
      ),
    );
  }
}
