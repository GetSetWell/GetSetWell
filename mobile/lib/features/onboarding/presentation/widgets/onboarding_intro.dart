import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';

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
                text: 'FITS YOUR LIFE.',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ),

        Text(
          'Tell us your goals, location, and schedule. We’ll help you find a verified trainer who feels right for you.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}
