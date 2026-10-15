import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// "ID, qualifications and references checked" row.
///
/// Figma: 12px padding, Border/Secondary 1px, radius 8, 20px badge,
/// Body/Small 12/16 white, 18px chevron. Only render it when the trainer
/// has at least one check to show (see [TrainerVerificationSheet.hasChecks]).
class TrainerVerificationRow extends StatelessWidget {
  const TrainerVerificationRow({super.key, this.onTap, this.nested = false});

  final VoidCallback? onTap;

  /// True inside a card (inner radius 8); false on the page (control 12).
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(nested ? GSWRadius.inner : GSWRadius.control),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GSWColors.backgroundSecondary,
            border: Border.all(color: GSWColors.borderSecondary),
            borderRadius: BorderRadius.circular(nested ? GSWRadius.inner : GSWRadius.control),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                GSWIcons.verified,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'ID, qualifications and references checked',
                  style: GSWTextStyles.bodySmall.copyWith(
                    color: GSWColors.textPrimary,
                    height: 16 / 12,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SvgPicture.asset(
                GSWIcons.arrowheadDown,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
