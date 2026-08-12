import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';

class TrainerMatchingCard extends StatelessWidget {
  const TrainerMatchingCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(GSWRadius.md),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Not sure who to pick?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: GSWColors.textPrimary),
                ),
              ),

              const SizedBox(width: 12),

              SvgPicture.asset(
                GSWIcons.helpChoose,
                width: GSWSizes.xs,
                height: GSWSizes.xs,
                colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Tell us your goal, your area and when you can train. '
            'A real person reads it and helps you narrow it down.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary, height: 1.4),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: GSWColors.textPrimary,
                backgroundColor: GSWColors.surfaceElevated,
                side: const BorderSide(color: GSWColors.borderSecondary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GSWRadius.full)),
              ),
              child: Text(
                'Tell us your situation',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: GSWColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
