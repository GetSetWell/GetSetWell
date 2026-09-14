import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/features/trainers/domain/models/trainer_verification_check.dart';

class TrainerVerificationItem {
  const TrainerVerificationItem({required this.title, required this.description});

  final String title;
  final String description;
}

class TrainerVerificationSheet extends StatelessWidget {
  const TrainerVerificationSheet({super.key, required this.trainerName, required this.items});

  final String trainerName;
  final List<TrainerVerificationCheck> items;

  static Future<void> show(
    BuildContext context, {
    required String trainerName,
    required List<TrainerVerificationCheck> items,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) {
        return TrainerVerificationSheet(trainerName: trainerName, items: items);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Container(
        decoration: const BoxDecoration(
          color: GSWColors.backgroundSecondary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(GSWRadius.xl),
            topRight: Radius.circular(GSWRadius.xl),
          ),
          border: Border(top: BorderSide(color: GSWColors.borderSecondary)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 16),

                Container(
                  width: 47,
                  height: 5,
                  decoration: BoxDecoration(
                    color: GSWColors.iconTertiary,
                    borderRadius: BorderRadius.circular(GSWRadius.full),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainerName.toUpperCase(),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(color: GSWColors.textPrimary),
                        ),

                        const SizedBox(height: 16),

                        const Divider(height: 1, color: GSWColors.borderDisabled),

                        const SizedBox(height: 16),

                        _buildVerificationHeading(context),

                        const SizedBox(height: 16),

                        ...items.map((item) => _buildVerificationItem(context, item)),

                        const SizedBox(height: 16),

                        const Divider(height: 1, color: GSWColors.borderSecondary),

                        const SizedBox(height: 16),

                        _buildDisclaimer(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                tooltip: 'Close',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                icon: const Icon(Icons.close_rounded, size: 22, color: GSWColors.iconTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationHeading(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          GSWIcons.verified,
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            'ID, qualifications and references checked',
            style:
                (Theme.of(context).extension<GSWTypography>()?.titleExtraSmall ??
                        GSWTextStyles.titleExtraSmall)
                    .copyWith(color: GSWColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationItem(BuildContext context, TrainerVerificationCheck item) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(color: GSWColors.primary, shape: BoxShape.circle),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: GSWColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  item.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: GSWColors.primary, width: 2)),
      ),
      child: Text(
        'What this cannot tell you: whether this trainer suits you personally, '
        'and it is not medical clearance. It narrows the uncertainty. '
        'It does not remove it.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: GSWColors.textPrimary),
      ),
    );
  }
}