import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';
import 'package:mobile/core/widgets/common/gsw_dashed_border.dart';

class GSWFilterChip extends StatelessWidget {
  const GSWFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconPath,
    this.isEnabled = true,
    this.trailing,
  });

  final String label;
  final String? iconPath;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isSelected ? GSWColors.primary : GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(GSWRadius.full),

        // Normal enabled filters use a solid border.
        // Disabled / coming-soon filters use GSWDashedBorder below.
        border: isEnabled
            ? Border.all(color: isSelected ? GSWColors.primary : GSWColors.borderSecondary)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null) ...[
            SvgPicture.asset(
              iconPath!,
              width: GSWSizes.icon,
              height: GSWSizes.icon,
              colorFilter: ColorFilter.mode(
                isSelected
                    ? GSWColors.iconInverse
                    : isEnabled
                    ? GSWColors.iconPrimary
                    : GSWColors.iconTertiary,
                BlendMode.srcIn,
              ),
            ),

            const SizedBox(width: 8),
          ],

          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? GSWColors.textInverse
                  : isEnabled
                  ? GSWColors.textPrimary
                  : GSWColors.textDisabled,
            ),
          ),

          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isEnabled ? onTap : null,
      child: isEnabled
          ? chip
          : GSWDashedBorder(
              color: GSWColors.borderSecondary,
              radius: GSWRadius.full,
              strokeWidth: 1,
              dashWidth: 4,
              dashGap: 4,
              child: chip,
            ),
    );
  }
}
