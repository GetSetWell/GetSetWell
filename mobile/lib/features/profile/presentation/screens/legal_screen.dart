import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(context),

                const SizedBox(height: 24),

                Text(
                  'Legal',
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 6),

                Text(
                  'The documents that apply when you use GetSetWell. Each one shows its version and the date it took effect.',
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),

                const SizedBox(height: 24),

                _buildLegalCard(),

                const SizedBox(height: 24),

                Text(
                  'Get Set Fit LLC, licence 2541939, Sharjah Media City (Shams), Sharjah, United Arab Emirates. Published in Arabic and English; if they differ, the Arabic version applies.',
                  style: GSWTextStyles.bodySmall.copyWith(
                    color: GSWColors.textSecondary,
                    height: 1.5,
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 30),
        ),
      ),
    );
  }

  Widget _buildLegalCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildLegalRow(
            icon: Icons.verified_outlined,
            title: 'Terms of Service',
            description: 'How booking, payment and your account work',
            version: 'Version 1.2 · 28 September 2026',
            onTap: onTermsOfService,
          ),

          _divider(),

          _buildLegalRow(
            icon: Icons.lock_outline,
            title: 'Privacy Policy',
            description: 'What we collect, why, and your rights',
            version: 'Version 1.2 · 28 September 2026',
            onTap: onPrivacyPolicy,
          ),

          _divider(),

          _buildLegalRow(
            icon: Icons.calendar_today_outlined,
            title: 'Cancellation and Refunds',
            description: 'What you get back, and when',
            version: 'Version 1.2 · 28 September 2026',
            onTap: onCancellationAndRefunds,
          ),

          _divider(),

          _buildLegalRow(
            icon: Icons.workspace_premium_outlined,
            title: 'Prohibited Services',
            description: 'What trainers may and may not offer',
            version: 'Version 1.2 · 28 September 2026',
            onTap: onProhibitedServices,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalRow({
    required IconData icon,
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
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: GSWColors.surfaceInteractive,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 24, color: GSWColors.primary),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      version,
                      style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              const Icon(Icons.chevron_right_rounded, size: 26, color: GSWColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: GSWColors.borderSecondary);
  }
}
