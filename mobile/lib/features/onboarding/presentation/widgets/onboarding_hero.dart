import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Welcome hero: photo with the two Figma gradients (dark at the top for the
/// logo, fading into the background at the bottom), logo pinned top-left.
///
/// Uses decorations rather than an Image so it has no intrinsic height and
/// simply fills the space the Welcome content leaves.
class OnboardingHero extends StatelessWidget {
  const OnboardingHero({super.key});

  static const Color _ink = GSWColors.backgroundPrimary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: GSWColors.backgroundPrimary,
            image: DecorationImage(
              image: AssetImage('assets/images/onboarding_hero.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _ink.withValues(alpha: 0.75),
                _ink.withValues(alpha: 0.5),
                _ink.withValues(alpha: 0),
              ],
              stops: const [0, 0.175, 0.35],
            ),
          ),
        ),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_ink.withValues(alpha: 0), _ink.withValues(alpha: 0.5), _ink],
              stops: const [0.693, 0.846, 1],
            ),
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Image.asset('assets/logos/logo.png', width: 30, height: 30),

                  const SizedBox(width: 4),

                  Text(
                    'GetSetWell',
                    style: GSWTextStyles.titleExtraSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 22 / 18,
                      color: GSWColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
