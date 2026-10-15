import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Figma: 24px tall, min width 72, 18px sides, Surface/Elevated fill,
/// Label/Small 12/12 in Text/Secondary.
class TrainerLanguagePill extends StatelessWidget {
  const TrainerLanguagePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: GSWColors.surfaceElevated,
        borderRadius: BorderRadius.circular(GSWRadius.full),
      ),
      // widthFactor 1 keeps the pill hugging its label inside a Wrap; an
      // aligned Container would stretch to the full row width.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: GSWTextStyles.labelSmall.copyWith(
            color: GSWColors.textSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}
