import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/auth/presentation/navigation/session_gate.dart';
import 'package:mobile/features/legal/presentation/widgets/legal_agreement_text.dart';

import '../presentation/widgets/onboarding_hero.dart';
import '../presentation/widgets/onboarding_intro.dart';

/// 1.2 Welcome. One lime action, one outlined action, one text link.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();

    // Splash never waits on a slow network. If someone is signed in but the
    // splash could not confirm their profile in time, keep resolving here.
    if (FirebaseAuth.instance.currentUser != null) {
      unawaited(_resolveInBackground());
    }
  }

  Future<void> _resolveInBackground() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final destination = await resolveSessionDestination(timeout: const Duration(seconds: 8));

      if (!mounted) return;

      // Only move the person if they are still on Welcome.
      final router = GoRouter.of(context);

      if (router.routeInformationProvider.value.uri.path != GSWRoutes.onboarding) return;

      // A pushed auth screen (sign in, OTP) sits above Welcome without
      // changing the path above, so also require Welcome to be the top route.
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;

      switch (destination) {
        case SessionDestination.home:
          context.go(GSWRoutes.home);
          return;

        case SessionDestination.details:
          context.go(GSWRoutes.userDetails, extra: const AuthFlowIntent.getStarted());
          return;

        case SessionDestination.welcome:
          return;

        case SessionDestination.unresolved:
          await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));

          if (!mounted) return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero fills whatever height the content leaves, but
                      // never collapses on short screens (the page scrolls).
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 320),
                          child: const OnboardingHero(),
                        ),
                      ),

                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const OnboardingIntro(),

                              const SizedBox(height: 20),

                              GSWButton(
                                size: GSWButtonSize.large,
                                label: 'Help me choose',
                                onPressed: () {
                                  context.push(GSWRoutes.helpMeChoose, extra: true);
                                },
                              ),

                              const SizedBox(height: 12),

                              GSWButton(
                                size: GSWButtonSize.large,
                                variant: GSWButtonVariant.secondary,
                                label: 'Get started',
                                onPressed: () {
                                  context.push(
                                    GSWRoutes.userAuth,
                                    extra: const AuthFlowIntent.getStarted(),
                                  );
                                },
                              ),

                              // 12px gap in Figma; 8px of it is tap padding.
                              const SizedBox(height: 4),

                              _ExistingAccountLink(
                                onTap: () {
                                  context.push(
                                    GSWRoutes.userAuth,
                                    extra: const AuthFlowIntent.existingAccount(),
                                  );
                                },
                              ),

                              // 20px gap in Figma; 8px is the link's tap padding.
                              const SizedBox(height: 12),

                              const LegalAgreementText.welcome(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExistingAccountLink extends StatelessWidget {
  const _ExistingAccountLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'I already have an account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 15,
              height: 20 / 15,
              color: GSWColors.textAccent,
            ),
          ),
        ),
      ),
    );
  }
}
