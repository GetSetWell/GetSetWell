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
import 'package:mobile/features/booking/domain/models/booking_checkout_data.dart';
import 'package:url_launcher/url_launcher.dart';

/// 5.5 Booking confirmed, and 11.4 Booked again for repeat bookings (same
/// layout, Figma 819:3411). Confirms, adds to calendar and gets out of the
/// way. Cancelling lives on the booking detail, where the refund can be stated.
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

  static const Duration _sessionLength = Duration(hours: 1);

  final BookingCheckoutData checkoutData;
  final String? referenceCode;
  final String? sessionId;

  /// Session start from the backend, ISO 8601 UTC.
  final String? scheduledAt;
  final String? locationLabel;
  final String? status;

  /// The server confirmed the session. Only then do we say "Paid".
  bool get _isConfirmed => status?.trim().toLowerCase() == 'confirmed';

  String get _firstName => BookingCopy.firstName(checkoutData.trainer.fullName);

  /// Session start, Dubai wall-clock time.
  DateTime get _start => GSWTime.parseToDubai(scheduledAt) ?? checkoutData.scheduledAt;

  /// Last moment to cancel for the session rate back, Dubai wall-clock time.
  DateTime get _freeCancellationCutoff => _start.subtract(const Duration(hours: 24));

  String get _location {
    final backend = locationLabel?.trim();

    if (backend != null && backend.isNotEmpty) return backend;

    return checkoutData.locationLabel;
  }

  String get _whereLabel => BookingCopy.whereLabel(
        venueChoice: checkoutData.venueChoice,
        customerTrainingPlace: checkoutData.customerTrainingPlace,
        locationLabel: _location,
        trainerGender: checkoutData.trainer.gender,
      );

  String get _cancellationNote {
    final rate = GSWMoney.aed(checkoutData.sessionRate);
    final cutoff = _freeCancellationCutoff;

    if (cutoff.isAfter(GSWTime.nowDubai())) {
      return 'Cancel before ${GSWTime.dayLong(cutoff)}, ${GSWTime.time(cutoff)} for the $rate session rate back';
    }

    return 'This session is less than 24 hours away. If you cancel, '
        '${GSWMoney.aed(GSWMoney.half(checkoutData.sessionRate))} of the $rate session rate comes back';
  }

  // ===========================================================================
  // CALENDAR
  // ===========================================================================

  Future<void> _addToCalendar(BuildContext context) async {
    String stamp(DateTime utc) {
      String two(int value) => value.toString().padLeft(2, '0');

      return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
          'T${two(utc.hour)}${two(utc.minute)}00Z';
    }

    final start = _start;
    final startUtc = GSWTime.dubaiToUtc(start.year, start.month, start.day, start.hour, start.minute);
    final endUtc = startUtc.add(_sessionLength);

    final reference = referenceCode?.trim() ?? '';

    final details = [
      'GetSetWell session with ${checkoutData.trainer.fullName}.',
      if (reference.isNotEmpty) 'Booking $reference.',
      'Manage or cancel in the GetSetWell app.',
    ].join(' ');

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Training with ${checkoutData.trainer.fullName}',
      'dates': '${stamp(startUtc)}/${stamp(endUtc)}',
      'ctz': 'Asia/Dubai',
      'details': details,
      'location': _location,
    });

    var opened = false;

    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Add to calendar failed: $error');
    }

    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: GSWColors.surfaceElevated,
          content: Text(
            'We couldn’t open your calendar. Your booking is saved in My sessions.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(GSWRoutes.home);
      },
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTop(),
                      const SizedBox(height: 24),
                      _buildSummary(),
                      const SizedBox(height: 24),
                      _buildBefore(),
                      if (_isConfirmed) ...[
                        const SizedBox(height: 24),
                        Text(
                          _cancellationNote,
                          textAlign: TextAlign.center,
                          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTop() {
    return Column(
      children: [
        SvgPicture.asset(
          GSWIcons.chatCheck,
          width: 96,
          height: 96,
          colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
        ),
        const SizedBox(height: 16),
        Text(
          !_isConfirmed
              ? 'BOOKING RECEIVED'
              : checkoutData.isRepeatBooking
                  ? 'BOOKED AGAIN'
                  : 'BOOKING CONFIRMED',
          textAlign: TextAlign.center,
          style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary, height: 1),
        ),
        const SizedBox(height: 16),
        Text(
          _isConfirmed
              ? checkoutData.isRepeatBooking
                  ? 'Same trainer, booked again. $_firstName knows.'
                  : '$_firstName knows. Everything below is also in My sessions.'
              : 'We are confirming this booking with $_firstName. We’ll let you know here as soon as it’s done.',
          textAlign: TextAlign.center,
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final reference = referenceCode?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Your booking',
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textSecondary, height: 1),
                ),
              ),
              if (reference.isNotEmpty)
                Text(
                  reference,
                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textAccent, height: 20 / 16),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: GSWColors.surfaceInteractive),
          const SizedBox(height: 10),
          Text(
            checkoutData.trainer.fullName,
            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary, height: 24 / 20),
          ),
          const SizedBox(height: 10),
          Text(
            '${GSWTime.dayLong(_start)}, ${GSWTime.timeRange(_start, _sessionLength)}',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
          ),
          const SizedBox(height: 10),
          Text(
            _whereLabel,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),
          const SizedBox(height: 10),
          Text(
            _isConfirmed
                ? 'Paid ${GSWMoney.aed(checkoutData.total)}'
                : 'Total ${GSWMoney.aed(checkoutData.total)}, waiting for payment confirmation',
            style: GSWTextStyles.labelMedium.copyWith(
              color: _isConfirmed ? GSWColors.textAccent : GSWColors.textSecondary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBefore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Before your session',
          style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary, height: 1),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
          ),
          child: Column(
            children: [
              _bullet('We’ll remind you the day before'),
              const SizedBox(height: 8),
              _bullet('Wear something you can move in'),
              const SizedBox(height: 8),
              _bullet('You each have 15 minutes’ grace if you’re running late'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    final style = GSWTextStyles.bodyMedium.copyWith(height: 20 / 14);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('·', style: style.copyWith(color: GSWColors.textAccent)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style.copyWith(color: GSWColors.textSecondary))),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GSWButton(
              label: 'Add to calendar',
              onPressed: () => _addToCalendar(context),
              variant: GSWButtonVariant.primary,
              size: GSWButtonSize.large,
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              child: InkWell(
                onTap: () => context.go(GSWRoutes.home),
                child: SizedBox(
                  width: double.infinity,
                  height: 20,
                  child: Center(
                    child: Text(
                      'Done',
                      style: GSWTextStyles.labelMedium.copyWith(
                        color: GSWColors.textSecondary,
                        height: 20 / 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
