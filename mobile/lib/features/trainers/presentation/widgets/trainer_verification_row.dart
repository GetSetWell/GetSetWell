import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';

class TrainerVerificationRow extends StatelessWidget {
  const TrainerVerificationRow({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GSWRadius.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: GSWColors.borderSecondary),
          borderRadius: BorderRadius.circular(GSWRadius.sm),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              GSWIcons.verified,
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
                'ID, qualifications and references checked',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: GSWColors.textPrimary),
              ),
            ),

            const SizedBox(width: 8),

            SvgPicture.asset(
              GSWIcons.arrowheadDown,
              width: GSWSizes.icon,
              height: GSWSizes.icon,
              colorFilter: const ColorFilter.mode(
                GSWColors.iconAccent,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
