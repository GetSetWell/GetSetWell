import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Welcome headline (Bebas 56/56) and line (Outfit 15/22).
class OnboardingIntro extends StatelessWidget {
  const OnboardingIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final headline = GSWTextStyles.displayLarge.copyWith(
      color: GSWColors.textPrimary,
      height: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: headline,
            children: [
              // Figma 1015:11347 copy. Bebas Neue is caps-only, so it
              // renders in capitals while screen readers get normal case.
              const TextSpan(text: 'FIND THE TRAINER\nWho '),
              TextSpan(
                text: 'fits your life.',
                style: headline.copyWith(color: GSWColors.textAccent),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Dubai trainers, checked before they appear. Choose yourself, or let us pick.',
          style: GSWTextStyles.bodyLarge.copyWith(
            fontSize: 15,
            height: 22 / 15,
            color: GSWColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
