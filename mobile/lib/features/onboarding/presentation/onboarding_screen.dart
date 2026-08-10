import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_spacing.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';

import '../../../../core/constants/gsw_icons.dart';
import '../presentation/widgets/onboarding_footer.dart';
import '../presentation/widgets/onboarding_hero.dart';
import '../presentation/widgets/onboarding_intro.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary, // Use the surface color from GSWColors
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full-width hero image
              const OnboardingHero(),

              const SizedBox(height: GSWSpacing.sm),

              // Padded page content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GSWSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Headline & Description
                    const OnboardingIntro(),
                    SizedBox(height: GSWSpacing.md),

                    // CTA
                    GSWButton(
                      size: GSWButtonSize.large,
                      label: 'Browse verified trainers',
                      trailingIcon: GSWIcons.arrowRight,
                      onPressed: () {
                        context.go('/trainers');
                      },
                    ),
                    SizedBox(height: GSWSpacing.sm),

                    GSWButton(
                      size: GSWButtonSize.large,
                      variant: GSWButtonVariant.secondary,
                      label: 'Help me choose',
                      trailingIcon: GSWIcons.helpChoose,
                      onPressed: () {},
                    ),
                    // Footer
                    const SizedBox(height: GSWSpacing.md),
                    const OnboardingFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
