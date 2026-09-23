import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_spacing.dart';

class OnboardingIntro extends StatelessWidget {
  const OnboardingIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'FIND THE TRAINER\n', style: Theme.of(context).textTheme.displayLarge),
              TextSpan(text: 'WHO ', style: Theme.of(context).textTheme.displayLarge),
              TextSpan(
                text: 'FITS YOUR\nLIFE.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ),

        SizedBox(height: GSWSpacing.sm),

        Text(
          'Dubai trainers, checked before they appear. Choose yourself, or let us pick.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }
}
