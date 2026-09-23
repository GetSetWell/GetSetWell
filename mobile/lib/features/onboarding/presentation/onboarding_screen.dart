import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_spacing.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/legal/presentation/widgets/legal_agreement_text.dart';

import '../presentation/widgets/onboarding_hero.dart';
import '../presentation/widgets/onboarding_intro.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero extends behind the status bar.
              // The header inside OnboardingHero
              // handles its own SafeArea.
              const OnboardingHero(),

              const SizedBox(height: GSWSpacing.xxs),

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GSWSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OnboardingIntro(),

                      const SizedBox(height: GSWSpacing.sm),

                      // -------------------------------------------------------
                      // HELP ME CHOOSE
                      // -------------------------------------------------------
                      GSWButton(
                        size: GSWButtonSize.large,
                        label: 'Help me choose',
                        onPressed: () {
                          context.push(GSWRoutes.helpMeChoose);
                        },
                      ),

                      const SizedBox(height: GSWSpacing.xs),

                      // -------------------------------------------------------
                      // NEW ACCOUNT
                      // -------------------------------------------------------
                      GSWButton(
                        size: GSWButtonSize.large,
                        variant: GSWButtonVariant.secondary,
                        label: 'Get Started',
                        onPressed: () {
                          context.push(
                            GSWRoutes.userAuth,
                            extra: const AuthFlowIntent.getStarted(),
                          );
                        },
                      ),

                      // -------------------------------------------------------
                      // EXISTING ACCOUNT
                      // -------------------------------------------------------
                      GSWButton(
                        size: GSWButtonSize.large,
                        variant: GSWButtonVariant.tertiary,
                        label: 'I already have an account',
                        onPressed: () {
                          context.push(
                            GSWRoutes.userAuth,
                            extra: const AuthFlowIntent.existingAccount(),
                          );
                        },
                      ),

                      const LegalAgreementText(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
