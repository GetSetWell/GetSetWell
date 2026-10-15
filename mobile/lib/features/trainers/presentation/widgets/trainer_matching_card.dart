import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// "Help me choose" card from Figma 7.3 / 8.1.
///
/// Default copy invites a new request. When a request is already open
/// (7.4), use [TrainerMatchingCard.requestOpen] which explains the
/// one-request rule and links to the open request instead.
class TrainerMatchingCard extends StatelessWidget {
  const TrainerMatchingCard({
    super.key,
    required this.onTap,
    this.title = 'Not sure who to pick?',
    this.body =
        'Tell us your goal, your area and when you can train. '
        'A real person reads it and helps you narrow it down.',
    this.buttonLabel = 'Tell us your situation',
  });

  const TrainerMatchingCard.requestOpen({super.key, required this.onTap})
    : title = 'Your request is being reviewed',
      body =
          "One request at a time gets a person's full attention. "
          'You can send a second once this one closes.',
      buttonLabel = 'See the request';

  final VoidCallback onTap;
  final String title;
  final String body;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfaceElevated,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.borderDisabled),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textPrimary,
                    height: 1,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              SvgPicture.asset(
                GSWIcons.helpChoose,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            body,
            style: GSWTextStyles.bodySmall.copyWith(
              color: GSWColors.textSecondary,
              height: 16 / 12,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: GSWColors.textPrimary,
                backgroundColor: GSWColors.surfaceElevated,
                side: const BorderSide(color: GSWColors.borderSecondary),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GSWRadius.full),
                ),
              ),
              child: Text(
                buttonLabel,
                style: GSWTextStyles.labelLarge.copyWith(
                  color: GSWColors.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
