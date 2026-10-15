import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/trainers/domain/models/trainer_verification_check.dart';

import 'trainer_sheet_frame.dart';

/// Figma 8.5 "What we checked": the evidence sheet behind the
/// "ID, qualifications and references checked" row.
///
/// Only checks that exist are listed. A check the trainer does not hold is
/// shown with a dash in Text/Secondary. "Met in person" rows are never shown:
/// GetSetWell does not claim to have met trainers.
class TrainerVerificationSheet extends StatelessWidget {
  const TrainerVerificationSheet({
    super.key,
    required this.trainerName,
    required this.items,
    this.closeLabel = 'Close',
  });

  final String trainerName;
  final List<TrainerVerificationCheck> items;

  /// Label of the secondary dismiss button. Figma 8.5 opened from the
  /// profile uses "Back to profile".
  final String closeLabel;

  /// Checks that may be shown to a client, in display order.
  static List<TrainerVerificationCheck> visibleChecks(List<TrainerVerificationCheck> items) {
    return items
        .where((item) => item.checkType.trim().toLowerCase() != 'in_person')
        .where((item) => item.title.trim().isNotEmpty || item.description.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// True when the trainer has at least one completed check to show.
  /// The "checked" row and badge are hidden otherwise.
  static bool hasChecks(List<TrainerVerificationCheck> items) {
    return visibleChecks(items).any((item) => item.isVerified);
  }

  static Future<void> show(
    BuildContext context, {
    required String trainerName,
    required List<TrainerVerificationCheck> items,
    String closeLabel = 'Close',
  }) {
    return TrainerSheetFrame.showFullHeight<void>(
      context,
      builder: (_) => TrainerVerificationSheet(
        trainerName: trainerName,
        items: items,
        closeLabel: closeLabel,
      ),
    );
  }

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String? get _checkedOnLabel {
    DateTime? latest;

    for (final item in visibleChecks(items)) {
      final date = item.verifiedAt;

      if (!item.isVerified || date == null) continue;

      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }

    if (latest == null) return null;

    // verified_at is a calendar date, so no time-zone shift applies.
    return '${latest.day} ${_months[latest.month - 1]} ${latest.year}';
  }

  @override
  Widget build(BuildContext context) {
    final checks = visibleChecks(items);
    final checkedOn = _checkedOnLabel;
    final name = trainerName.trim();

    final subtitle = checkedOn == null ? name : '$name, checked $checkedOn';

    return Column(
      children: [
        const TrainerSheetGrabber(),

        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text('What we checked', style: trainerSheetHeadingStyle()),

                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  Text(
                    subtitle,
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: GSWColors.textSecondary,
                      height: 20 / 14,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (checks.isEmpty)
                  Text(
                    'There are no checks to show for this trainer yet.',
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: GSWColors.textSecondary,
                      height: 20 / 14,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GSWColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(GSWRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int index = 0; index < checks.length; index++) ...[
                          _CheckLine(check: checks[index]),
                          if (index != checks.length - 1) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                Text(
                  'We re-check every 12 months.',
                  style: GSWTextStyles.bodySmall.copyWith(
                    color: GSWColors.textTertiary,
                    height: 16 / 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'We check documents and references. We do not meet trainers in person.',
                  style: GSWTextStyles.bodySmall.copyWith(
                    color: GSWColors.textTertiary,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        TrainerSheetBottomBar(
          child: GSWButton(
            label: closeLabel,
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.check});

  final TrainerVerificationCheck check;

  String get _text {
    final title = check.title.trim();
    final description = check.description.trim();

    if (!check.isVerified) {
      return title.isEmpty ? description : '$title: not held';
    }

    return description.isNotEmpty ? description : title;
  }

  @override
  Widget build(BuildContext context) {
    final held = check.isVerified;

    // Figma 8.5: held checks white with a lime Medium tick; checks not held
    // are Text/Tertiary throughout.
    final textStyle = GSWTextStyles.bodyMedium.copyWith(
      color: held ? GSWColors.textPrimary : GSWColors.textTertiary,
      height: 20 / 14,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: held ? 12 : 13,
          child: Text(
            held ? '✓' : '–',
            style: textStyle.copyWith(
              color: held ? GSWColors.textAccent : GSWColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(child: Text(_text, style: textStyle)),
      ],
    );
  }
}
