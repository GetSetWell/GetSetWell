import 'package:flutter/material.dart';

import '../../../../core/theme/gsw_spacing.dart';
import '../../../../core/widgets/common/header.dart';
import '../widgets/onboarding_verification_badge.dart';

class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: double.infinity,
      height: screenWidth * 1.15,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Edge-to-edge background image
          Image.asset(
            'assets/images/onboarding_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),

          // Header layered over the image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(GSWSpacing.xs, GSWSpacing.xs, GSWSpacing.xs, 0),
                child: Header(),
              ),
            ),
          ),

          // Verification badge layered over the image
          Positioned(
            left: GSWSpacing.xs,
            bottom: GSWSpacing.xs,
            child: const VerifiedTrainerBadge(),
          ),
        ],
      ),
    );
  }
}
