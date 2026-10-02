import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

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
                  'Language',
                  style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose the language for the app.',
                  style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                ),

                const SizedBox(height: 24),

                _buildLanguageCard(),

                const SizedBox(height: 24),

                Text(
                  'Arabic is coming soon, with the app laid out right to left. Until then, GetSetWell is in English.',
                  style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
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

  Widget _buildLanguageCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildEnglishRow(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: GSWColors.borderSecondary),
          ),

          _buildArabicRow(),
        ],
      ),
    );
  }

  Widget _buildEnglishRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'English',
              style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
            ),
          ),

          _buildSelectedIndicator(),
        ],
      ),
    );
  }

  Widget _buildArabicRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Opacity(
              opacity: 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'العربية',
                    style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'Arabic',
                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          _buildComingSoonPill(),
        ],
      ),
    );
  }

  Widget _buildSelectedIndicator() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GSWColors.primary, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: GSWColors.primary),
      ),
    );
  }

  Widget _buildComingSoonPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Coming soon',
        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
      ),
    );
  }
}
