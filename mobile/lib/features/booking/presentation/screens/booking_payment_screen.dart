import 'dart:async';
import 'dart:convert';

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
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Payment step of direct booking, with the Story 6 states:
/// 6.1 Payment failed, 6.2 Awaiting confirmation, 6.3 Slot taken.
///
/// The Pay button calls create-booking-request. Tap is wired into this
/// step later; until then the server confirms the session directly.
class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen({super.key, required this.checkoutData});

  final BookingCheckoutData checkoutData;

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

enum _PaymentState { ready, processing, failed, awaiting, slotTaken }

class _FailureCopy {
  const _FailureCopy({
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.primaryAction = _FailureAction.retry,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final _FailureAction primaryAction;
}

enum _FailureAction { retry, signIn, completeProfile }

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  static const Duration _sessionLength = Duration(hours: 1);
  static const Duration _requestTimeout = Duration(seconds: 30);

  final SupabaseClient _client = Supabase.instance.client;

  late BookingCheckoutData _checkout = widget.checkoutData;

  _PaymentState _state = _PaymentState.ready;

  _FailureCopy? _failure;

  /// True when the slot failed validation (in the past or no longer offered)
  /// rather than being taken by someone else.
  bool _slotNoLongerOffered = false;

  DateTime? _selectedAlternative;

  bool _isChecking = false;

  String? _knownSessionId;

  String get _firstName => BookingCopy.firstName(_checkout.trainer.fullName);

  Object? get _gender => _checkout.trainer.gender;

  String get _service {
    final value = _checkout.trainer.primaryService?.trim();

    if (value == null || value.isEmpty) return 'Personal training';

    return GSWPronoun.capitalise(value);
  }

  String get _whereLabel => BookingCopy.whereLabel(
        venueChoice: _checkout.venueChoice,
        customerTrainingPlace: _checkout.customerTrainingPlace,
        locationLabel: _checkout.locationLabel,
        trainerGender: _gender,
      );

  String get _whenShort =>
      '${GSWTime.dayShort(_checkout.scheduledAt)}, ${GSWTime.timeRange(_checkout.scheduledAt, _sessionLength)}';

  // ===========================================================================
  // PAY
  // ===========================================================================

  Map<String, dynamic> get _requestBody {
    final source = _checkout.sourceConciergeRequestId?.trim() ?? '';
    final goal = _checkout.goal?.trim() ?? '';
    final notes = _checkout.notes?.trim() ?? '';

    return {
      'request_type': 'trainer_request',
      'trainer_id': _checkout.trainer.id,
      if (source.isNotEmpty) 'source_concierge_request_id': source,
      'scheduled_at': _checkout.scheduledAtUtcIso,
      'customer_training_place': switch (_checkout.customerTrainingPlace) {
        CustomerTrainingPlace.gym => 'gym',
        CustomerTrainingPlace.home => 'home',
        CustomerTrainingPlace.outdoors => 'outdoors',
      },
      'venue_choice': switch (_checkout.venueChoice) {
        BookingVenueChoice.customerChoice => 'customer_choice',
        BookingVenueChoice.trainerPrivateGym => 'trainer_private_gym',
      },
      'location_label': _checkout.locationLabel,
      // Exactly the amounts shown on screen, computed in fils by GSWMoney.
      'session_rate': _checkout.sessionRate,
      'service_fee': _checkout.serviceFee,
      'total': _checkout.total,
      'payment_method': switch (_checkout.paymentMethod) {
        BookingPaymentMethod.card => 'card',
        BookingPaymentMethod.applePay => 'apple_pay',
      },
      if (goal.isNotEmpty) 'goal': goal,
      if (notes.isNotEmpty) 'message': notes,
    };
  }

  Future<void> _pay() async {
    if (_state == _PaymentState.processing) return;

    setState(() {
      _state = _PaymentState.processing;
      _failure = null;
    });

    try {
      final response = await _client.functions
          .invoke('create-booking-request', body: _requestBody)
          .timeout(_requestTimeout);

      final data = response.data;

      if (data is! Map) {
        await _recoverUnknownOutcome(timedOut: false);
        return;
      }

      await _handleSuccess(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      if (error.status == 0) {
        // The request may not have reached the server, or the answer was lost.
        await _recoverUnknownOutcome(timedOut: false);
        return;
      }

      _handleFunctionError(error.status, _decodeDetails(error.details));
    } on TimeoutException {
      await _recoverUnknownOutcome(timedOut: true);
    } catch (error) {
      debugPrint('Booking payment failed: $error');
      await _recoverUnknownOutcome(timedOut: false);
    }
  }

  Map<String, dynamic> _decodeDetails(Object? details) {
    if (details is Map) return Map<String, dynamic>.from(details);

    if (details is String && details.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {'error': details};
      }
    }

    return const {};
  }

  void _handleFunctionError(int status, Map<String, dynamic> body) {
    if (!mounted) return;

    final error = body['error']?.toString().trim() ?? '';
    final details = body['details'];
    final detailText = details is List
        ? details.map((value) => value.toString().toLowerCase()).join(' | ')
        : (details?.toString().toLowerCase() ?? '');

    if (status == 409 && error == 'SLOT_TAKEN') {
      _showSlotTaken(noLongerOffered: false);
      return;
    }

    // The live (older) booking function reports a price change as a 400
    // "session rate does not match backend price"; the new one as 409.
    if ((status == 409 && error == 'PRICE_CHANGED') ||
        (status == 400 && detailText.contains('does not match backend price'))) {
      // The review step reloads the price and shows the new total.
      context.pop(BookingPaymentOutcome.priceChanged);
      return;
    }

    if (status == 400 &&
        (detailText.contains('in the past') || detailText.contains('outside the trainer availability'))) {
      _showSlotTaken(noLongerOffered: true);
      return;
    }

    if (status == 401) {
      _showFailure(
        const _FailureCopy(
          title: 'Sign in to finish booking',
          body: 'Your sign-in has expired. Sign in again with your mobile number, then pay. You have not been charged.',
          primaryLabel: 'Sign in',
          primaryAction: _FailureAction.signIn,
        ),
      );
      return;
    }

    if (status == 409 && error.toLowerCase() == 'profile incomplete') {
      _showFailure(
        const _FailureCopy(
          title: 'Add your name and city',
          body: 'We need your name and city before we can book a session. You have not been charged.',
          primaryLabel: 'Complete profile',
          primaryAction: _FailureAction.completeProfile,
        ),
      );
      return;
    }

    _showFailure(_paymentFailedCopy);
  }

  _FailureCopy get _paymentFailedCopy {
    final start = _checkout.scheduledAt;

    return _FailureCopy(
      title: 'Payment didn’t go through',
      body: 'Your card was not charged. Your ${GSWTime.time(start)} slot on '
          '${GSWTime.dayLong(start)} is not booked yet, so try again soon.',
      primaryLabel: 'Try again',
    );
  }

  void _showFailure(_FailureCopy copy) {
    if (!mounted) return;

    setState(() {
      _failure = copy;
      _state = _PaymentState.failed;
    });
  }

  void _showSlotTaken({required bool noLongerOffered}) {
    if (!mounted) return;

    final taken = _checkout.scheduledAt;

    setState(() {
      _slotNoLongerOffered = noLongerOffered;
      _checkout = _checkout.copyWith(
        availableStarts: _checkout.availableStarts.where((value) => value != taken).toList(),
      );
      final alternatives = _alternatives;
      _selectedAlternative = alternatives.isEmpty ? null : alternatives.first;
      _state = _PaymentState.slotTaken;
    });
  }

  /// The answer was lost or never arrived. Look for the session before
  /// telling the person anything, so they never pay twice.
  Future<void> _recoverUnknownOutcome({required bool timedOut}) async {
    final found = await _findExistingSession();

    if (!mounted) return;

    if (found != null) {
      await _handleSuccess(found);
      return;
    }

    if (timedOut) {
      setState(() {
        _state = _PaymentState.awaiting;
      });
      return;
    }

    _showFailure(_paymentFailedCopy);
  }

  Future<void> _handleSuccess(Map<String, dynamic> data) async {
    if (!mounted) return;

    final sessionId = (data['session_id'] ?? data['id'])?.toString();

    if (sessionId != null && sessionId.isNotEmpty) {
      _knownSessionId = sessionId;
    }

    final status = data['status']?.toString().trim().toLowerCase() ?? '';

    if (status == 'cancelled' || status == 'canceled' || status == 'failed') {
      _showFailure(_paymentFailedCopy);
      return;
    }

    if (status != 'confirmed') {
      setState(() {
        _state = _PaymentState.awaiting;
      });
      return;
    }

    final sessionRate = GSWMoney.parse(data['session_rate']);
    final serviceFee = GSWMoney.parse(data['service_fee']);
    final total = GSWMoney.parse(data['total_amount']);

    final confirmed = _checkout.copyWith(
      sessionRate: sessionRate,
      serviceFee: serviceFee,
      total: total,
    );

    context.go(
      GSWRoutes.bookingConfirmation,
      extra: {
        'checkoutData': confirmed,
        'referenceCode': data['reference_code']?.toString(),
        'sessionId': _knownSessionId,
        'scheduledAt': data['scheduled_at']?.toString(),
        'locationLabel': data['location_label']?.toString(),
        'status': status,
      },
    );
  }

  /// Finds this person's session for this trainer and start time, if the
  /// server created one. Returns it in the edge function's response shape.
  Future<Map<String, dynamic>?> _findExistingSession() async {
    try {
      // `*` so a database without the price snapshot columns still answers.
      final sessionId = _knownSessionId;

      final Map<String, dynamic>? row = sessionId != null
          ? await _client.from('sessions').select('*').eq('id', sessionId).maybeSingle()
          : await _client
              .from('sessions')
              .select('*')
              .eq('trainer_id', _checkout.trainer.id)
              .eq('scheduled_at', _checkout.scheduledAtUtcIso)
              .neq('status', 'cancelled')
              .limit(1)
              .maybeSingle();

      if (row == null) return null;

      final result = Map<String, dynamic>.from(row);
      result['session_id'] = row['id'];

      final requestId = row['booking_request_id']?.toString();

      if (requestId != null && requestId.isNotEmpty) {
        final request = await _client
            .from('booking_requests')
            .select('reference_code')
            .eq('id', requestId)
            .maybeSingle();

        result['reference_code'] = request?['reference_code'];
      }

      return result;
    } catch (error) {
      debugPrint('Booking status lookup failed: $error');
      return null;
    }
  }

  Future<void> _checkAgain() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    final found = await _findExistingSession();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
    });

    if (found != null) {
      await _handleSuccess(found);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: GSWColors.surfaceElevated,
          content: Text(
            'No answer yet. We’ll keep the booking in My sessions once it’s confirmed.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),
        ),
      );
  }

  Future<void> _runFailureAction() async {
    final action = _failure?.primaryAction ?? _FailureAction.retry;

    switch (action) {
      case _FailureAction.retry:
        await _pay();

      case _FailureAction.signIn:
        await context.push(GSWRoutes.userAuth, extra: const AuthFlowIntent.returnToCaller());
        if (!mounted) return;
        setState(() => _state = _PaymentState.ready);

      case _FailureAction.completeProfile:
        await context.push(GSWRoutes.editProfile);
        if (!mounted) return;
        setState(() => _state = _PaymentState.ready);
    }
  }

  void _useAlternative() {
    final start = _selectedAlternative;

    if (start == null) return;

    setState(() {
      _checkout = _checkout.copyWith(scheduledAt: start);
      _state = _PaymentState.ready;
    });
  }

  /// The two nearest open times after the one that went, same trainer.
  List<DateTime> get _alternatives {
    final now = GSWTime.nowDubai();
    final taken = _checkout.scheduledAt;

    final future = _checkout.availableStarts
        .where((value) => value.isAfter(now) && value != taken)
        .toList()
      ..sort((a, b) => a.difference(taken).abs().compareTo(b.difference(taken).abs()));

    final nearest = future.take(2).toList()..sort();

    return nearest;
  }

  void _close() {
    if (_state == _PaymentState.processing) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(GSWRoutes.home);
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isResult = _state == _PaymentState.failed ||
        _state == _PaymentState.awaiting ||
        _state == _PaymentState.slotTaken;

    return PopScope(
      canPop: _state != _PaymentState.processing && _state != _PaymentState.awaiting,
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          bottom: false,
          child: isResult ? _buildResultState() : _buildReadyState(),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ===========================================================================
  // READY / PROCESSING
  // ===========================================================================

  Widget _buildReadyState() {
    final processing = _state == _PaymentState.processing;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Opacity(
                opacity: processing ? 0.4 : 1,
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: processing ? null : _close,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: GSWColors.borderSecondary),
                        ),
                        child: SvgPicture.asset(
                          GSWIcons.arrowheadLeft,
                          width: 30,
                          height: 30,
                          colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Secure payment',
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment',
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
                ),
                const SizedBox(height: 8),
                Text(
                  processing
                      ? 'Paying now. Please keep this screen open.'
                      : 'Check your total, then pay to confirm your session.',
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 24),
                _buildPaymentMethodCard(),
                const SizedBox(height: 24),
                _buildPriceCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _checkout.trainer.fullName,
            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _whenShort,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            _whereLabel,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final label = switch (_checkout.paymentMethod) {
      BookingPaymentMethod.card => 'Card',
      BookingPaymentMethod.applePay => 'Apple Pay',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay with',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.control),
            border: Border.all(color: GSWColors.primary, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
                ),
              ),
              const Icon(Icons.check_circle_rounded, color: GSWColors.primary, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        children: [
          _priceRow('Session, 60 minutes', _checkout.sessionRate),
          const SizedBox(height: 10),
          _priceRow('Service fee (5%)', _checkout.serviceFee),
          const SizedBox(height: 10),
          Container(height: 1, color: GSWColors.surfaceInteractive),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                ),
              ),
              Text(
                GSWMoney.aed(_checkout.total),
                style: GSWTextStyles.headingSmall.copyWith(color: GSWColors.textAccent, height: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
        ),
        Text(
          GSWMoney.aed(amount),
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
        ),
      ],
    );
  }

  // ===========================================================================
  // RESULT STATES (6.1, 6.2, 6.3)
  // ===========================================================================

  /// Figma 6.1 to 6.3: content column (24px sides, 24px gaps) centred
  /// vertically between the status bar and the bottom bar; scrolls when tall.
  Widget _buildResultState() {
    final List<Widget> content = switch (_state) {
      _PaymentState.awaiting => _buildAwaitingContent(),
      _PaymentState.slotTaken => _buildSlotTakenContent(),
      _ => _buildFailedContent(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                ...content,
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 72px state circle: Surface/Primary fill and a 2px ring.
  Widget _stateIcon(Widget child, {Color ring = GSWColors.surfaceInteractive}) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GSWColors.surfacePrimary,
          border: Border.all(color: ring, width: 2),
        ),
        child: child,
      ),
    );
  }

  Widget _stateTitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
    );
  }

  Widget _stateBody(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
    );
  }

  /// Booking summary card shared by 6.1 and 6.2.
  Widget _resultSummary(String footnote) {
    return Container(
      // Figma 16/14 padding; Flutter adds the 1px border on top.
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${_checkout.trainer.fullName} · $_service',
                  style: GSWTextStyles.labelLarge.copyWith(
                    color: GSWColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 21 / 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                GSWMoney.aed(_checkout.total),
                style: GSWTextStyles.labelLarge.copyWith(
                  color: GSWColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 21 / 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_whenShort · $_whereLabel',
            style: GSWTextStyles.bodySmall.copyWith(
              color: GSWColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footnote,
            style: GSWTextStyles.bodySmall.copyWith(
              color: GSWColors.textAccent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFailedContent() {
    final copy = _failure ?? _paymentFailedCopy;

    return [
      _stateIcon(
        Text(
          '!',
          style: GSWTextStyles.titleExtraLarge.copyWith(
            color: GSWColors.iconError,
            fontSize: 34,
            height: 1,
          ),
        ),
        ring: GSWColors.borderError,
      ),
      const SizedBox(height: 24),
      _stateTitle(copy.title),
      const SizedBox(height: 24),
      _stateBody(copy.body),
      const SizedBox(height: 24),
      _resultSummary('Not booked yet, nothing charged'),
    ];
  }

  List<Widget> _buildAwaitingContent() {
    final start = _checkout.scheduledAt;

    return [
      _stateIcon(
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: GSWColors.textSecondary,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      const SizedBox(height: 24),
      _stateTitle('Waiting on your bank'),
      const SizedBox(height: 24),
      // Figma says the slot "is held meanwhile". There is no hold on the
      // server, so the copy does not promise one.
      _stateBody(
        'Your bank has the payment and hasn’t answered yet. This usually takes a minute or two. '
        'Your ${GSWTime.time(start)} slot on ${GSWTime.dayLong(start)} is confirmed once it does. '
        'If the payment doesn’t go through, you won’t be charged, and we’ll tell you here.',
      ),
      const SizedBox(height: 24),
      _resultSummary('Waiting for your bank to answer'),
    ];
  }

  List<Widget> _buildSlotTakenContent() {
    final taken = _checkout.scheduledAt;
    final alternatives = _alternatives;

    return [
      _stateIcon(
        SvgPicture.asset(
          GSWIcons.calendar,
          width: 28,
          height: 28,
          colorFilter: const ColorFilter.mode(GSWColors.textSecondary, BlendMode.srcIn),
        ),
      ),
      const SizedBox(height: 24),
      _stateTitle('That time just went'),
      const SizedBox(height: 24),
      _stateBody(
        _slotNoLongerOffered
            ? '${GSWTime.time(taken)} on ${GSWTime.dayLong(taken)} is no longer available. You were not charged, and your card has not been touched.'
            : 'Someone booked ${GSWTime.time(taken)} while you were paying. You were not charged, and your card has not been touched.',
      ),
      const SizedBox(height: 24),
      if (alternatives.isEmpty)
        _stateBody('$_firstName has no other open times this week. Pick another day or trainer.')
      else ...[
        Text(
          'OTHER TIMES WITH ${_firstName.toUpperCase()}',
          style: GSWTextStyles.bodySmall.copyWith(
            color: GSWColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 15 / 11,
          ),
        ),
        for (final start in alternatives) ...[
          const SizedBox(height: 10),
          _buildAlternative(start, taken),
        ],
      ],
    ];
  }

  Widget _buildAlternative(DateTime start, DateTime taken) {
    final selected = _selectedAlternative == start;

    final String relation;
    if (GSWTime.isSameDay(start, taken)) {
      relation = 'Same day';
    } else if (GSWTime.isSameDay(start, taken.add(const Duration(days: 1)))) {
      relation = start.hour < 12 ? 'Next morning' : 'Next day';
    } else {
      relation = GSWTime.relativeDay(start);
    }

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedAlternative = start),
          borderRadius: BorderRadius.circular(GSWRadius.control),
          child: Container(
            // Figma 16/14 padding; Flutter adds the 1px border on top.
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            decoration: BoxDecoration(
              color: GSWColors.surfacePrimary,
              borderRadius: BorderRadius.circular(GSWRadius.control),
              border: Border.all(
                color: selected ? GSWColors.primary : GSWColors.surfaceInteractive,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${GSWTime.dayShort(start)}, ${GSWTime.timeRange(start, _sessionLength)}',
                        style: GSWTextStyles.labelLarge.copyWith(
                          color: GSWColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 21 / 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$relation · $_whereLabel',
                        style: GSWTextStyles.bodySmall.copyWith(
                          color: GSWColors.textSecondary,
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Figma: solid lime 20px dot when selected, grey ring otherwise.
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? GSWColors.primary : null,
                    border: selected
                        ? null
                        : Border.all(color: GSWColors.borderSecondary, width: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM BAR
  // ===========================================================================

  Widget _buildBottomBar() {
    switch (_state) {
      case _PaymentState.ready:
      case _PaymentState.processing:
        final processing = _state == _PaymentState.processing;
        return _bottomShell(
          primary: GSWButton(
            label: processing ? 'Paying' : 'Pay ${GSWMoney.aed(_checkout.total)}',
            onPressed: processing ? null : _pay,
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
            isLoading: processing,
          ),
          footer: Text(
            'Payments are processed securely by our payment provider. Your card details never reach GetSetWell.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textSecondary, height: 14 / 11),
          ),
        );

      case _PaymentState.failed:
        final action = _failure?.primaryAction ?? _FailureAction.retry;
        return _resultBottomShell(
          primary: GSWButton(
            label: (_failure ?? _paymentFailedCopy).primaryLabel,
            onPressed: _runFailureAction,
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
          ),
          footer: _textAction(
            action == _FailureAction.retry ? 'Use a different card' : 'Back to review',
            action == _FailureAction.retry
                ? () => context.pop(BookingPaymentOutcome.changePaymentMethod)
                : _close,
          ),
        );

      case _PaymentState.awaiting:
        return _resultBottomShell(
          primary: GSWButton(
            label: 'Check again',
            onPressed: _isChecking ? null : _checkAgain,
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
            isLoading: _isChecking,
          ),
          footer: _textAction('Go to my sessions', () => context.go(GSWRoutes.sessions, extra: 1)),
        );

      case _PaymentState.slotTaken:
        final alternative = _selectedAlternative;
        final hasAlternative = alternative != null;
        return _resultBottomShell(
          primary: GSWButton(
            label: alternative != null
                ? 'Book ${GSWTime.time(alternative)} instead'
                : 'See all ${GSWPronoun.possessive(_gender)} times',
            onPressed: hasAlternative
                ? _useAlternative
                : () => context.pop(BookingPaymentOutcome.pickAnotherTime),
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
          ),
          footer: hasAlternative
              ? _textAction(
                  'See all ${GSWPronoun.possessive(_gender)} times',
                  () => context.pop(BookingPaymentOutcome.pickAnotherTime),
                )
              : null,
        );
    }
  }

  /// Figma 6.x text action: Outfit Medium 14, line 20, Text/Accent.
  Widget _textAction(String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 20,
          child: Center(
            child: Text(
              label,
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textAccent, height: 20 / 14),
            ),
          ),
        ),
      ),
    );
  }

  /// Figma 6.x bottom bar: no fill, 16px sides and top, 28px bottom
  /// (plus the device inset), 12px between the button and the text action.
  Widget _resultBottomShell({required Widget primary, Widget? footer}) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          primary,
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _bottomShell({required Widget primary, Widget? footer}) {
    return Container(
      color: GSWColors.surfacePrimary,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              primary,
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
