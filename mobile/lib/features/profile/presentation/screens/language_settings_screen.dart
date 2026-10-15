import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

/// 12.7 Language (Figma 1077:3629).
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(context),

                const SizedBox(height: 24),

                Text(
                  'Language',
                  style: GSWTextStyles.titleLarge.copyWith(
                    height: 30 / 24,
                    color: GSWColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Choose the language for the app.',
                  style: GSWTextStyles.bodyMedium.copyWith(
                    height: 20 / 14,
                    color: GSWColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                _buildLanguageCard(),

                const SizedBox(height: 24),

                Text(
                  'Arabic is coming soon, with the app laid out right to left. Until then, GetSetWell is in English.',
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

  Widget _buildLanguageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Column(
        children: [
          _buildEnglishRow(),

          const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),

          _buildArabicRow(),
        ],
      ),
    );
  }

  Widget _buildEnglishRow() {
    return Semantics(
      selected: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'English',
                style: GSWTextStyles.bodyLarge.copyWith(height: 1, color: GSWColors.textPrimary),
              ),
            ),

            const SizedBox(width: 14),

            _buildSelectedIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildArabicRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'العربية',
                  textDirection: TextDirection.rtl,
                  style: GSWTextStyles.bodyLarge.copyWith(
                    height: 1,
                    color: GSWColors.textTertiary,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Arabic',
                  style: GSWTextStyles.bodyMedium.copyWith(
                    height: 20 / 14,
                    color: GSWColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

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
        borderRadius: BorderRadius.circular(GSWRadius.full),
      ),
      child: Text(
        'Coming soon',
        style: GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textSecondary),
      ),
    );
  }
}
