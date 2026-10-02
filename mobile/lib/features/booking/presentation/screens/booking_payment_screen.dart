import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen({super.key, required this.checkoutData});

  final BookingCheckoutData checkoutData;

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  bool _isProcessing = false;

  BookingCheckoutData get checkoutData => widget.checkoutData;

  Future<void> _pay() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final client = Supabase.instance.client;

      final response = await client.functions.invoke(
        'create-booking-request',

        body: {
          'request_type': 'trainer_request',

          'trainer_id': checkoutData.trainer.id,

          if (checkoutData.sourceConciergeRequestId != null &&
              checkoutData.sourceConciergeRequestId!.trim().isNotEmpty)
            'source_concierge_request_id': checkoutData.sourceConciergeRequestId!.trim(),

          'scheduled_at': _scheduledAtDubaiIso(checkoutData.scheduledAt),

          'customer_training_place': _customerTrainingPlaceValue(
            checkoutData.customerTrainingPlace,
          ),

          'venue_choice': _venueChoiceValue(checkoutData.venueChoice),

          'location_label': checkoutData.locationLabel,

          'session_rate': checkoutData.sessionRate,

          'service_fee': checkoutData.serviceFee,

          'total': checkoutData.total,

          'payment_method': _paymentMethodValue(checkoutData.paymentMethod),

          if (checkoutData.goal != null && checkoutData.goal!.trim().isNotEmpty)
            'goal': checkoutData.goal!.trim(),

          if (checkoutData.notes != null && checkoutData.notes!.trim().isNotEmpty)
            'message': checkoutData.notes!.trim(),
        },
      );

      if (response.status != 201) {
        throw Exception('Booking failed: ${response.data}');
      }

      final data = Map<String, dynamic>.from(response.data as Map);

      if (!mounted) return;

      context.go(
        GSWRoutes.bookingConfirmation,

        extra: {
          'checkoutData': checkoutData,

          'referenceCode': data['reference_code']?.toString(),

          'sessionId': data['session_id']?.toString(),

          'scheduledAt': data['scheduled_at']?.toString(),

          'locationLabel': data['location_label']?.toString(),

          'status': data['status']?.toString(),
        },
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to complete booking: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        bottom: false,

        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      'Payment',

                      style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Review your total before continuing.',

                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                    ),

                    const SizedBox(height: 28),

                    _buildBookingSummary(),

                    const SizedBox(height: 24),

                    _buildPaymentMethod(),

                    const SizedBox(height: 24),

                    _buildPriceBreakdown(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: _buildBottomAction(),
    );
  }

  String _customerTrainingPlaceValue(CustomerTrainingPlace value) {
    switch (value) {
      case CustomerTrainingPlace.gym:
        return 'gym';

      case CustomerTrainingPlace.home:
        return 'home';

      case CustomerTrainingPlace.outdoors:
        return 'outdoors';
    }
  }

  String _venueChoiceValue(BookingVenueChoice value) {
    switch (value) {
      case BookingVenueChoice.customerChoice:
        return 'customer_choice';

      case BookingVenueChoice.trainerPrivateGym:
        return 'trainer_private_gym';
    }
  }

  String _paymentMethodValue(BookingPaymentMethod value) {
    switch (value) {
      case BookingPaymentMethod.card:
        return 'card';

      case BookingPaymentMethod.applePay:
        return 'apple_pay';
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),

      child: Row(
        children: [
          Material(
            color: Colors.transparent,

            child: InkWell(
              onTap: () {
                context.pop();
              },

              customBorder: const CircleBorder(),

              child: Container(
                width: 46,

                height: 46,

                alignment: Alignment.center,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  border: Border.all(color: GSWColors.borderSecondary),
                ),

                child: const Icon(Icons.chevron_left_rounded, size: 30, color: GSWColors.primary),
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
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            checkoutData.trainer.fullName,

            style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 6),

          Text(
            checkoutData.locationLabel,

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 6),

          Text(
            _dateTimeLabel(checkoutData.scheduledAt),

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text('Pay with', style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary)),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,

          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,

            borderRadius: BorderRadius.circular(12),

            border: Border.all(color: GSWColors.primary),
          ),

          child: Row(
            children: [
              const Icon(Icons.credit_card_rounded, color: GSWColors.primary, size: 22),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  _paymentMethodLabel,

                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
                ),
              ),

              const Icon(Icons.check_circle_rounded, color: GSWColors.primary, size: 20),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Review your booking and complete payment to confirm your session.',

          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        children: [
          _priceRow(label: 'Session, 60 minutes', amount: checkoutData.sessionRate),

          const SizedBox(height: 10),

          _priceRow(label: 'Service fee (5%)', amount: checkoutData.serviceFee),

          const SizedBox(height: 12),

          const Divider(height: 1, color: GSWColors.borderSecondary),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',

                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
                ),
              ),

              Text(
                'AED ${_money(checkoutData.total)}',

                style: GSWTextStyles.headingSmall.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow({required String label, required double amount}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),

        Text(
          'AED ${_money(amount)}',

          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
        ),
      ],
    );
  }

  String _scheduledAtDubaiIso(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${value.year.toString().padLeft(4, '0')}-'
        '${twoDigits(value.month)}-'
        '${twoDigits(value.day)}T'
        '${twoDigits(value.hour)}:'
        '${twoDigits(value.minute)}:'
        '${twoDigits(value.second)}'
        '+04:00';
  }

  Widget _buildBottomAction() {
    return Container(
      color: GSWColors.surfacePrimary,

      child: SafeArea(
        top: false,

        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),

          child: GSWButton(
            label: _isProcessing ? 'Processing...' : 'Pay AED ${_money(checkoutData.total)}',

            onPressed: _isProcessing ? null : _pay,

            variant: _isProcessing ? GSWButtonVariant.disabled : GSWButtonVariant.primary,

            size: GSWButtonSize.large,

            isLoading: _isProcessing,
          ),
        ),
      ),
    );
  }

  String get _paymentMethodLabel {
    switch (checkoutData.paymentMethod) {
      case BookingPaymentMethod.card:
        return 'Card';

      case BookingPaymentMethod.applePay:
        return 'Apple Pay';
    }
  }

  String _dateTimeLabel(DateTime date) {
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

    return '${weekdays[date.weekday - 1]}, '
        '${date.day} '
        '${months[date.month - 1]} '
        'at ${_time(date)}';
  }

  String _time(DateTime date) {
    var hour = date.hour;

    final period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
