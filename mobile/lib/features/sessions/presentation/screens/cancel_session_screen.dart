import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
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
    final customerId = await CustomerIdentityService(client: _client).getCustomerId();
    if (widget.sessionId.trim().isEmpty) {
      throw Exception('Missing session ID.');
    }
    final sessionRow = await _client
        .from('sessions')
        .select('''
          id,
          booking_request_id,
          trainer_id,
          scheduled_at,
          location_label,
          status,
          trainers(
            id,
            full_name,
            profile_image_url,
            price_per_session
          )
        ''')
        .eq('id', widget.sessionId)
        .eq('user_id', customerId)
        .single();
    final session = Map<String, dynamic>.from(sessionRow);
    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');
    if (scheduledAt == null) {
      throw Exception('Session has no scheduled time.');
    }
    Map<String, dynamic> request = {};
    final bookingRequestId = session['booking_request_id']?.toString().trim() ?? '';
    if (bookingRequestId.isNotEmpty) {
      final requestRow = await _client
          .from('booking_requests')
          .select('''
            id,
            reference_code,
            created_at
          ''')
          .eq('id', bookingRequestId)
          .eq('user_id', customerId)
          .maybeSingle();
      if (requestRow != null) {
        request = Map<String, dynamic>.from(requestRow);
      }
    }
    final trainerRaw = session['trainers'];
    final trainer = trainerRaw is Map ? Map<String, dynamic>.from(trainerRaw) : <String, dynamic>{};
    return _CancelSessionData(
      session: session,
      request: request,
      trainer: trainer,
      scheduledAtDubai: _toDubai(scheduledAt),
    );
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
      final message = switch (error.message) {
        'SESSION_NOT_CANCELLABLE' => 'This session can no longer be cancelled.',
        'SESSION_NOT_FOUND' => 'We could not find this session.',
        _ => 'We could not cancel this session. Please try again.',
      };
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 24),
                  Text(
                    'Cancel this session?',
                    style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_longDate(data.scheduledAtDubai)}, '
                    '${_timeLabel(data.scheduledAtDubai)} '
                    'with ${data.trainerName}',
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: GSWColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPolicyCard(data, calculation),
                  const SizedBox(height: 24),
                  Text(
                    'Why are you cancelling? Optional.',
                    style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
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
    return InkWell(
      onTap: () => context.pop(false),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GSWColors.neutral700),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 34),
      ),
    );
  }

  Widget _buildPolicyCard(_CancelSessionData data, _CancellationCalculation calculation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calculation.headline,
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            calculation.body(
              trainerName: data.trainerName,
              sessionRate: data.sessionRate,
              serviceFee: data.serviceFee,
            ),
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChips() {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
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
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? GSWColors.surfaceInteractive : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
        ),
        child: Text(
          reason,
          style: GSWTextStyles.bodySmall.copyWith(
            color: selected ? GSWColors.textPrimary : GSWColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(_CancelSessionData data, _CancellationCalculation calculation) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isCancelling ? null : () => _cancelSession(data),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF26D6D),
              disabledForegroundColor: const Color(0xFFF26D6D).withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'Cancel and refund ${_money(calculation.refundAmount)}',
              style: GSWTextStyles.bodyLarge.copyWith(
                color: _isCancelling
                    ? const Color(0xFFF26D6D).withValues(alpha: 0.45)
                    : const Color(0xFFF26D6D),
                fontWeight: FontWeight.w500,
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

  DateTime _toDubai(DateTime value) {
    return value.toUtc().add(const Duration(hours: 4));
  }

  String _longDate(DateTime value) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[value.weekday - 1]} '
        '${value.day} '
        '${months[value.month - 1]}';
  }

  String _timeLabel(DateTime value) {
    var hour = value.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour %= 12;
    if (hour == 0) {
      hour = 12;
    }
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _money(double value) {
    final hasDecimals = value != value.roundToDouble();
    return hasDecimals ? 'AED ${value.toStringAsFixed(2)}' : 'AED ${value.toStringAsFixed(0)}';
  }
}

class _CancelSessionData {
  const _CancelSessionData({
    required this.session,
    required this.request,
    required this.trainer,
    required this.scheduledAtDubai,
  });
  final Map<String, dynamic> session;
  final Map<String, dynamic> request;
  final Map<String, dynamic> trainer;
  final DateTime scheduledAtDubai;
  String get trainerName => trainer['full_name']?.toString().trim().isNotEmpty == true
      ? trainer['full_name'].toString().trim()
      : 'your trainer';
  double get sessionRate {
    final raw = trainer['price_per_session'];
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  double get serviceFee => sessionRate * 0.05;
  _CancellationCalculation get cancellationCalculation {
    final nowDubai = DateTime.now().toUtc().add(const Duration(hours: 4));
    final difference = scheduledAtDubai.difference(nowDubai);
    final hours = difference.inMinutes / 60;
    if (difference.inMinutes >= 24 * 60) {
      return _CancellationCalculation(
        hoursBeforeSession: hours,
        refundAmount: sessionRate,
        isLate: false,
      );
    }
    return _CancellationCalculation(
      hoursBeforeSession: hours,
      refundAmount: sessionRate * 0.5,
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
    required String trainerName,
    required double sessionRate,
    required double serviceFee,
  }) {
    final rateText = _formatMoney(sessionRate);
    final serviceFeeText = _formatMoney(serviceFee);
    final refundText = _formatMoney(refundAmount);
    if (!isLate) {
      return '24 hours or more before, so you get the '
          '$rateText session fee back and the '
          '$serviceFeeText service fee is kept. '
          'The refund goes to the card you paid with in '
          '5 to 10 working days. Nothing goes to '
          '$trainerName and your slot is released.';
    }
    return 'Inside 24 hours, so you get $refundText back. '
        'The service fee is kept. The remaining half of the '
        'session fee goes to $trainerName for holding the time. '
        'The refund goes to the card you paid with in '
        '5 to 10 working days and your slot is released.';
  }

  static String _formatMoney(double value) {
    final hasDecimals = value != value.roundToDouble();
    return hasDecimals ? 'AED ${value.toStringAsFixed(2)}' : 'AED ${value.toStringAsFixed(0)}';
  }
}
