import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

/// 12.5 Legal (Figma 819:3659).
class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.onTermsOfService,
    required this.onPrivacyPolicy,
    required this.onCancellationAndRefunds,
    required this.onProhibitedServices,
  });

  final VoidCallback onTermsOfService;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onCancellationAndRefunds;
  final VoidCallback onProhibitedServices;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(context),

                const SizedBox(height: 24),

                Text(
                  'Legal',
                  style: GSWTextStyles.titleLarge.copyWith(
                    height: 30 / 24,
                    color: GSWColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'The documents that apply when you use GetSetWell. Each one shows its version and the date it took effect.',
                  style: GSWTextStyles.bodyMedium.copyWith(
                    height: 20 / 14,
                    color: GSWColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                _buildLegalCard(),

                const SizedBox(height: 24),

                Text(
                  'Get Set Fit LLC, licence 2541939, Sharjah Media City (Shams), Sharjah, United Arab Emirates. Published in Arabic and English; if they differ, the Arabic version applies.',
                  style: GSWTextStyles.bodySmall.copyWith(
                    height: 16 / 12,
                    color: GSWColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            GSWIcons.arrowheadLeft,
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildLegalRow(
            icon: _svgIcon(GSWIcons.verified),
            title: 'Terms of Service',
            description: 'How booking, payment and your account work',
            version: 'Version 1.3 · 14 October 2026',
            onTap: onTermsOfService,
          ),

          _divider(),

          _buildLegalRow(
            icon: const Icon(Icons.lock_outline_rounded, size: 20, color: GSWColors.iconAccent),
            title: 'Privacy Policy',
            description: 'What we collect, why, and your rights',
            version: 'Version 1.3 · 14 October 2026',
            onTap: onPrivacyPolicy,
          ),

          _divider(),

          _buildLegalRow(
            icon: _svgIcon(GSWIcons.calendar),
            title: 'Cancellation and Refunds',
            description: 'What you get back, and when',
            version: 'Version 1.2 · 28 September 2026',
            onTap: onCancellationAndRefunds,
          ),

          _divider(),

          _buildLegalRow(
            icon: const Icon(
              Icons.workspace_premium_outlined,
              size: 20,
              color: GSWColors.iconAccent,
            ),
            title: 'Prohibited Services',
            description: 'What trainers may and may not offer',
            version: 'Version 1.2 · 28 September 2026',
            onTap: onProhibitedServices,
          ),
        ],
      ),
    );
  }

  Widget _svgIcon(String asset) {
    return SvgPicture.asset(
      asset,
      width: 20,
      height: 20,
      colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
    );
  }

  Widget _buildLegalRow({
    required Widget icon,
    required String title,
    required String description,
    required String version,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: GSWColors.surfaceInteractive,
                  borderRadius: BorderRadius.circular(GSWRadius.inner),
                ),
                alignment: Alignment.center,
                child: icon,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GSWTextStyles.bodyLarge.copyWith(
                        height: 1,
                        color: GSWColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      description,
                      style: GSWTextStyles.bodySmall.copyWith(
                        height: 16 / 12,
                        color: GSWColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      version,
                      style: GSWTextStyles.bodyExtraSmall.copyWith(
                        height: 1,
                        color: GSWColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              SvgPicture.asset(
                GSWIcons.arrowheadRight,
                width: 16.667,
                height: 20,
                colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive);
  }
}
