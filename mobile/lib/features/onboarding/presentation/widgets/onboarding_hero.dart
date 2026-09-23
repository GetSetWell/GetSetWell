import 'package:flutter/material.dart';

import '../../../../core/widgets/common/header.dart';

class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: double.infinity,
      height: screenWidth * 1.1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image already contains the final gradient.
          Image.asset(
            'assets/images/onboarding_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),

          // Keep only the header inside the safe area.
          // The image itself can extend behind the status bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: const Header(showNotifications: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
