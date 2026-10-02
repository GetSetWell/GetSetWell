import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_sizes.dart';

class TrainerSessionDetailRow extends StatelessWidget {
  const TrainerSessionDetailRow({
    super.key,
    required this.iconPath,
    required this.text,
  });

  final String iconPath;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          iconPath,
          width: GSWSizes.icon,
          height: GSWSizes.icon,
          colorFilter: const ColorFilter.mode(
            GSWColors.iconAccent,
            BlendMode.srcIn,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
