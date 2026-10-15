import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CancelSessionScreen extends StatefulWidget {
  const CancelSessionScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  State<CancelSessionScreen> createState() => _CancelSessionScreenState();
}

class _CancelSessionScreenState extends State<CancelSessionScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  late Future<_CancelSessionData> _dataFuture;
  String? _selectedReason;
  bool _isCancelling = false;
  static const List<String> _reasons = [
    'Schedule clash',
    'Not well',
    'Changed my mind',
    'Found someone else',
    'Other',
  ];
  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_CancelSessionData> _loadData() async {
    final session = await SessionsService(_client).getSession(widget.sessionId);
    final start = sessionStartDubai(session);
    if (start == null) {
      throw Exception('Session has no scheduled time.');
    }
    return _CancelSessionData(session: session, scheduledAtDubai: start);
  }

  Future<void> _cancelSession(_CancelSessionData data) async {
    if (_isCancelling) return;
    setState(() {
      _isCancelling = true;
    });
    try {
      await _client.rpc(
        'cancel_session',
        params: {'p_session_id': widget.sessionId, 'p_reason': _selectedReason},
      );
      if (!mounted) return;
      context.go(GSWRoutes.sessionCancelled, extra: widget.sessionId);
    } on PostgrestException catch (error) {
      debugPrint('Cancel session failed: ${error.code} ${error.message}');
      if (!mounted) return;
      final message = error.message.contains('SESSION_NOT_CANCELLABLE')
          ? 'This session has started or is no longer booked, so it cannot be cancelled.'
          : error.message.contains('SESSION_NOT_FOUND')
              ? 'We could not find this session.'
              : 'We could not cancel this session. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      debugPrint('Cancel session failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not cancel this session. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: FutureBuilder<_CancelSessionData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }
            if (snapshot.hasError || snapshot.data == null) {
              debugPrint('Cancel session load failed: ${snapshot.error}');
              return _buildErrorState();
            }
            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(_CancelSessionData data) {
    final calculation = data.cancellationCalculation;
    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 24),
                  Text(
                    'Cancel this session?',
                    style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
                  ),
                  // 10.3 groups title and line with a 6px gap (6.4 shows 24; 10.3 is the newer frame).
                  const SizedBox(height: 6),
                  Text(
                    '${GSWTime.dayLong(data.scheduledAtDubai)}, '
                    '${GSWTime.time(data.scheduledAtDubai)} '
                    'with ${data.trainerName}',
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: GSWColors.textSecondary,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPolicyCard(data, calculation),
                  const SizedBox(height: 24),
                  Text(
                    'Why are you cancelling? Optional.',
                    style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
                  ),
                  const SizedBox(height: 12),
                  _buildReasonChips(),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(data, calculation),
      ],
    );
  }

  Widget _buildBackButton() {
    return SessionBackButton(onTap: () => context.pop(false));
  }

  Widget _buildPolicyCard(_CancelSessionData data, _CancellationCalculation calculation) {
    return Container(
      width: double.infinity,
      // Figma 16 from the outer edge; the 1px lime border is added by the decoration.
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calculation.headline,
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary, height: 22 / 16),
          ),
          const SizedBox(height: 8),
          Text(
            calculation.body(
              trainerFirstName: data.trainerFirstName,
              sessionRate: data.sessionRate,
              serviceFee: data.serviceFee,
            ),
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final reason in _reasons) _buildReasonChip(reason)],
    );
  }

  Widget _buildReasonChip(String reason) {
    final selected = _selectedReason == reason;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedReason = selected ? null : reason;
        });
      },
      borderRadius: BorderRadius.circular(GSWRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? GSWColors.surfaceInteractive : Colors.transparent,
          borderRadius: BorderRadius.circular(GSWRadius.full),
          border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
        ),
        child: Text(
          reason,
          style: GSWTextStyles.bodySmall.copyWith(
            fontSize: 13,
            height: 18 / 13,
            color: selected ? GSWColors.textPrimary : GSWColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(_CancelSessionData data, _CancellationCalculation calculation) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      color: GSWColors.backgroundPrimary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GSWButton(
            size: GSWButtonSize.large,
            variant: GSWButtonVariant.primary,
            label: 'Keep my session',
            onPressed: _isCancelling ? null : () => context.pop(false),
          ),
          const SizedBox(height: 12),
          // Figma: a full-width Medium 14 / 20 line in status/error.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isCancelling || data.sessionRate == null ? null : () => _cancelSession(data),
            child: SizedBox(
              width: double.infinity,
              height: 20,
              child: Center(
                child: _isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: GSWColors.error),
                      )
                    : Text(
                        data.sessionRate == null
                            ? 'Cancel and refund'
                            : 'Cancel and refund ${GSWMoney.aed(calculation.refundAmount)}',
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.labelMedium.copyWith(
                          height: 20 / 14,
                          color: data.sessionRate == null
                              ? GSWColors.error.withValues(alpha: 0.45)
                              : GSWColors.error,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load this session.',
              textAlign: TextAlign.center,
              style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again.',
              textAlign: TextAlign.center,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),
            const SizedBox(height: 24),
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.primary,
              label: 'Try again',
              onPressed: () {
                setState(() {
                  _dataFuture = _loadData();
                });
              },
            ),
            const SizedBox(height: 8),
            GSWButton(
              size: GSWButtonSize.medium,
              variant: GSWButtonVariant.tertiary,
              label: 'Go back',
              onPressed: () => context.pop(false),
            ),
          ],
        ),
      ),
    );
  }

}

class _CancelSessionData {
  _CancelSessionData({required this.session, required this.scheduledAtDubai})
      : trainer = SessionTrainerInfo.fromSession(session),
        amounts = SessionAmounts.fromSession(session);

  final Map<String, dynamic> session;
  final DateTime scheduledAtDubai;
  final SessionTrainerInfo trainer;
  final SessionAmounts amounts;

  String get trainerName => trainer.name;

  String get trainerFirstName => trainer.firstName;

  /// Session rate from the booking snapshot (trainer price only for legacy rows).
  double? get sessionRate => amounts.sessionRate;

  double? get serviceFee => amounts.serviceFee;

  /// Mirrors cancel_session: 24h or more returns the session rate, under 24h
  /// half of it. The fee is kept either way. The server stores the final figure.
  _CancellationCalculation get cancellationCalculation {
    final difference = scheduledAtDubai.difference(GSWTime.nowDubai());
    final hours = difference.inMinutes / 60;
    final double rate = sessionRate ?? 0;
    if (difference.inMinutes >= 24 * 60) {
      return _CancellationCalculation(hoursBeforeSession: hours, refundAmount: rate, isLate: false);
    }
    return _CancellationCalculation(
      hoursBeforeSession: hours,
      refundAmount: GSWMoney.half(rate),
      isLate: true,
    );
  }
}

class _CancellationCalculation {
  const _CancellationCalculation({
    required this.hoursBeforeSession,
    required this.refundAmount,
    required this.isLate,
  });
  final double hoursBeforeSession;
  final double refundAmount;
  final bool isLate;
  String get headline {
    final rounded = hoursBeforeSession.floor();
    if (rounded <= 0) {
      return 'This session is starting soon.';
    }
    return 'You are cancelling $rounded '
        '${rounded == 1 ? 'hour' : 'hours'} \n'
        'before the session.';
  }

  String body({
    required String trainerFirstName,
    required double? sessionRate,
    required double? serviceFee,
  }) {
    final rateText = GSWMoney.aed(sessionRate);
    final feeText = serviceFee == null ? 'service fee' : '${GSWMoney.aed(serviceFee)} service fee';
    final refundText = GSWMoney.aed(refundAmount);
    if (!isLate) {
      return '24 hours or more before, so you get the $rateText session fee back and the '
          '$feeText is kept. The refund goes to the card you paid with in 5 to 10 working days. '
          'Nothing goes to $trainerFirstName and your slot is released.';
    }
    return 'Less than 24 hours before, so you get $refundText back, half the session fee. '
        'The other half goes to $trainerFirstName for holding the time, and the $feeText is kept. '
        'The refund goes to the card you paid with in 5 to 10 working days.';
  }
}
