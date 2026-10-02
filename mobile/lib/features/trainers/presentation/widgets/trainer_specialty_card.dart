import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

import '../../../../core/theme/gsw_colors.dart';

class TrainerSpecialtyCard extends StatelessWidget {
  const TrainerSpecialtyCard({
    super.key,
    required this.label,
    required this.iconPath,
  });

  final String label;
  final String iconPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              GSWColors.iconAccent,
              BlendMode.srcIn,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            label,
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
