import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.checkoutData,
    this.referenceCode,
    this.sessionId,
    this.scheduledAt,
    this.locationLabel,
    this.status,
  });

  final BookingCheckoutData checkoutData;
  final String? referenceCode;
  final String? sessionId;
  final String? scheduledAt;
  final String? locationLabel;
  final String? status;

  bool get _isConfirmed {
    return status?.trim().toLowerCase() == 'confirmed';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildConfirmedSuccessHeader(),

                      const SizedBox(height: 24),

                      _buildBookingCard(),

                      const SizedBox(height: 24),

                      Text(
                        'Before your session',
                        style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 8),

                      _buildInfoCard(),
                      const SizedBox(height: 24),

                      Text(
                        'Cancel before ${_cancelDateRange(_confirmedScheduledAt)} for the AED ${_money(checkoutData.sessionRate)} session fee back',
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),

              _buildBottomAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your booking',
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textSecondary),
                ),
              ),

              Text(
                referenceCode ?? 'Booking',
                style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Divider(height: 1, color: GSWColors.surfaceInteractive),

          const SizedBox(height: 10),

          Text(
            checkoutData.trainer.fullName,
            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 10),

          Text(
            _sessionDateRange(_confirmedScheduledAt),
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 10),

          Text(
            _bookingLocationLabel,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 10),

          Text(
            'Paid AED ${_money(checkoutData.total)}',
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.primary),
          ),
        ],
      ),
    );
  }

  String _cancelDateRange(DateTime start) {
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

    return '${weekdays[start.weekday - 2]} '
        '${start.day - 1} '
        '${months[start.month - 1]}, '
        '${_time(start)}';
  }

  String _sessionDateRange(DateTime start) {
    final end = start.add(const Duration(hours: 1));

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

    return '${weekdays[start.weekday - 1]} '
        '${start.day} '
        '${months[start.month - 1]}, '
        '${_time(start)} to ${_time(end)}';
  }

  String get _bookingLocationLabel {
    switch (checkoutData.venueChoice) {
      case BookingVenueChoice.trainerPrivateGym:
        return 'His gym, $_confirmedLocationLabel';

      case BookingVenueChoice.customerChoice:
        switch (checkoutData.customerTrainingPlace) {
          case CustomerTrainingPlace.gym:
            return 'Your gym, $_confirmedLocationLabel';

          case CustomerTrainingPlace.home:
            return 'Your home, $_confirmedLocationLabel';

          case CustomerTrainingPlace.outdoors:
            return 'Outdoors, $_confirmedLocationLabel';
        }
    }
  }

  DateTime get _confirmedScheduledAt {
    final backendValue = DateTime.tryParse(scheduledAt ?? '');

    return backendValue ?? checkoutData.scheduledAt;
  }

  String get _confirmedLocationLabel {
    final backendValue = locationLabel?.trim();

    if (backendValue != null && backendValue.isNotEmpty) {
      return backendValue;
    }

    return checkoutData.locationLabel;
  }

  Widget _buildInfoCard() {
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
          _bullet('We’ll remind you before your session.'),

          const SizedBox(height: 8),

          _bullet('Wear something comfortable to move in.'),

          const SizedBox(height: 8),

          _bullet('Your trainer will receive your booking details.'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(color: GSWColors.primary, shape: BoxShape.circle),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedSuccessHeader() {
    return Column(
      children: [
        SvgPicture.asset(
          GSWIcons.chatCheck,
          width: 96,
          height: 96,
          colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
        ),

        const SizedBox(height: 24),

        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Booking ',
                style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary),
              ),
              TextSpan(
                text: _isConfirmed ? 'CONFIRMED' : 'RECEIVED',
                style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textAccent),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${checkoutData.trainer.fullName} knows. We will send everything below to you on WhatsApp.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      width: double.infinity,
      color: GSWColors.surfacePrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: GSWButton(
            label: 'Done',
            onPressed: () {
              context.go(GSWRoutes.home);
            },
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
          ),
        ),
      ),
    );
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
