import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';

const Duration _sessionDuration = Duration(hours: 1);

// Shown only after the database confirms the free reschedule.

// Late changes must pass through a server-confirmed payment first.

class SessionMovedScreen extends StatelessWidget {
  const SessionMovedScreen({
    required this.trainerName,

    required this.originalAt,

    required this.newAt,

    required this.location,

    required this.bookingReference,

    required this.onDone,
  });

  final String trainerName;

  final DateTime originalAt;

  final DateTime newAt;

  final String location;

  final String? bookingReference;

  final VoidCallback onDone;

  static const _months = [
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

  static const _weekdays = [
    'Monday',

    'Tuesday',

    'Wednesday',

    'Thursday',

    'Friday',

    'Saturday',

    'Sunday',
  ];

  String _fullDate(DateTime value) =>
      '${_weekdays[value.weekday - 1]} ${value.day} ${_months[value.month - 1]}';

  String _shortDate(DateTime value) =>
      '${_weekdays[value.weekday - 1].substring(0, 3)} ${value.day} '
      '${_months[value.month - 1].substring(0, 3)}';

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

    final period = value.hour < 12 ? 'AM' : 'PM';

    return '$hour:${value.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,

      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,

        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),

            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,

                      children: [
                        const SizedBox(height: 12),

                        Center(
                          child: Icon(
                            Icons.check_circle_outline_rounded,

                            size: 98,

                            color: GSWColors.primary,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'SESSION MOVED',

                          textAlign: TextAlign.center,

                          style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          'Your new session time is confirmed.',

                          textAlign: TextAlign.center,

                          style: GSWTextStyles.bodyLarge.copyWith(
                            color: GSWColors.textSecondary,

                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 26),

                        Container(
                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: GSWColors.surfacePrimary,

                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Your booking',

                                      style: GSWTextStyles.bodyMedium.copyWith(
                                        color: GSWColors.textSecondary,
                                      ),
                                    ),
                                  ),

                                  if (bookingReference != null)
                                    Text(
                                      bookingReference!,

                                      style: GSWTextStyles.labelMedium.copyWith(
                                        color: GSWColors.primary,
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Divider(height: 1, color: GSWColors.neutral700),

                              const SizedBox(height: 14),

                              Text(
                                trainerName,

                                style: GSWTextStyles.titleMedium.copyWith(
                                  color: GSWColors.textPrimary,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                '${_fullDate(newAt)}, ${_time(newAt)} to '
                                '${_time(newAt.add(_sessionDuration))}',

                                style: GSWTextStyles.bodyMedium.copyWith(
                                  color: GSWColors.textPrimary,
                                ),
                              ),

                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 10),

                                Text(
                                  location,

                                  style: GSWTextStyles.bodyMedium.copyWith(
                                    color: GSWColors.textSecondary,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              Text(
                                'Moved from ${_shortDate(originalAt)}, ${_time(originalAt)}.',

                                style: GSWTextStyles.bodySmall.copyWith(
                                  color: GSWColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        Align(
                          alignment: Alignment.centerLeft,

                          child: Text(
                            'Good to know',

                            style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          width: double.infinity,

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: GSWColors.surfacePrimary,

                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Text(
                            '•  This booking cannot be moved again.\n\n'
                            '•  You can still cancel it under the applicable cancellation policy.',

                            style: GSWTextStyles.bodyMedium.copyWith(
                              color: GSWColors.textSecondary,

                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                GSWButton(
                  size: GSWButtonSize.large,

                  variant: GSWButtonVariant.primary,

                  label: 'Back to my session',

                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
