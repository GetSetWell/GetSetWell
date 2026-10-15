import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 10.2b Session moved (free) and 10.2e Session moved, paid.
///
/// Shown only after the server confirmed the move. `paidAmount` is null for a
/// free move and the amount charged for a late (paid) move.
class SessionMovedScreen extends StatelessWidget {
  const SessionMovedScreen({
    super.key,
    required this.session,
    required this.originalStart,
    required this.newStart,
    required this.movedAt,
    this.paidAmount,
  });

  /// The session row as loaded before the move (trainer, place, reference).
  final Map<String, dynamic> session;

  /// Dubai wall-clock times.
  final DateTime originalStart;
  final DateTime newStart;
  final DateTime movedAt;

  final double? paidAmount;

  @override
  Widget build(BuildContext context) {
    final trainer = SessionTrainerInfo.fromSession(session);
    final amounts = SessionAmounts.fromSession(session);
    final location = session['location_label']?.toString().trim() ?? '';

    final request = session['booking_requests'];
    final reference = request is Map ? request['reference_code']?.toString().trim() ?? '' : '';

    final cutoff = newStart.subtract(const Duration(hours: 24));
    final wasLate = originalStart.difference(movedAt) < const Duration(hours: 24);

    final paidText = paidAmount == null ? 'No charge.' : 'Paid ${GSWMoney.aed(paidAmount)}.';

    final cancelLine = amounts.sessionRate == null
        ? 'You can still cancel it. Cancel before ${GSWTime.dayLong(cutoff)}, ${GSWTime.time(cutoff)} to get the session fee back.'
        : 'You can still cancel it. Cancel before ${GSWTime.dayLong(cutoff)}, ${GSWTime.time(cutoff)} to get the ${GSWMoney.aed(amounts.sessionRate)} session fee back.';

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SvgPicture.asset(
                          GSWIcons.chatCheck,
                          width: 72,
                          height: 72,
                          colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: GSWTextStyles.displayLarge.copyWith(
                            color: GSWColors.textPrimary,
                            height: 1,
                          ),
                          children: const [
                            TextSpan(text: 'SESSION '),
                            TextSpan(text: 'MOVED', style: TextStyle(color: GSWColors.textAccent)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "${trainer.firstName} knows. We've sent the new time to you on WhatsApp.",
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.bodyMedium.copyWith(
                          color: GSWColors.textSecondary,
                          height: 20 / 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Your booking',
                                    style: GSWTextStyles.labelLarge.copyWith(
                                      color: GSWColors.textSecondary,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                if (reference.isNotEmpty)
                                  Text(
                                    reference,
                                    style: GSWTextStyles.labelLarge.copyWith(
                                      color: GSWColors.textAccent,
                                      height: 20 / 16,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
                            const SizedBox(height: 10),
                            Text(
                              trainer.name,
                              style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${GSWTime.dayLong(newStart)}, ${GSWTime.timeRange(newStart, kSessionLength)}',
                              style: GSWTextStyles.bodyMedium.copyWith(
                                color: GSWColors.textPrimary,
                                height: 20 / 14,
                              ),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                location,
                                style: GSWTextStyles.bodyMedium.copyWith(
                                  color: GSWColors.textSecondary,
                                  height: 20 / 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              'Moved from ${GSWTime.dayShort(originalStart)}, ${GSWTime.time(originalStart)}. $paidText',
                              style: GSWTextStyles.labelMedium.copyWith(
                                color: GSWColors.textSecondary,
                                height: 1,
                              ),
                            ),
                            if (paidAmount != null) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your receipt will be available here once card payments are live.'),
                                  ),
                                ),
                                child: Text(
                                  'View receipt',
                                  style: GSWTextStyles.bodyMedium.copyWith(
                                    color: GSWColors.textAccent,
                                    fontWeight: FontWeight.w500,
                                    height: 20 / 14,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Good to know',
                        style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary, height: 1),
                      ),
                      const SizedBox(height: 8),
                      _card(
                        Column(
                          children: [
                            const SessionBullet("This booking can't be moved again."),
                            const SizedBox(height: 8),
                            SessionBullet(cancelLine),
                            const SizedBox(height: 8),
                            const SessionBullet("We'll remind you on WhatsApp the day before."),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        // Figma: long date on 10.2b, short date on 10.2e.
                        wasLate
                            ? 'Moved ${GSWTime.dayAndTime(movedAt)}, inside 24 hours of the session.'
                            : 'Moved ${GSWTime.dayLong(movedAt)}, ${GSWTime.time(movedAt)}, more than 24 hours before the session.',
                        textAlign: TextAlign.center,
                        style: GSWTextStyles.bodySmall.copyWith(
                          color: GSWColors.textTertiary,
                          height: 16 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GSWButton(
                      label: 'Add to calendar',
                      onPressed: () => _addToCalendar(context, trainer, location),
                    ),
                    const SizedBox(height: 8),
                    GSWButton(
                      label: 'Back to my session',
                      variant: GSWButtonVariant.tertiary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: child,
    );
  }

  /// Opens a prefilled calendar event in the browser or calendar app.
  Future<void> _addToCalendar(
    BuildContext context,
    SessionTrainerInfo trainer,
    String location,
  ) async {
    String stamp(DateTime dubai) {
      final utc = GSWTime.dubaiToUtc(dubai.year, dubai.month, dubai.day, dubai.hour, dubai.minute);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}00Z';
    }

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Session with ${trainer.name}',
      'dates': '${stamp(newStart)}/${stamp(newStart.add(kSessionLength))}',
      if (location.isNotEmpty) 'location': location,
      'details': 'Booked through GetSetWell.',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't open your calendar. Please try again.")),
      );
    }
  }
}
