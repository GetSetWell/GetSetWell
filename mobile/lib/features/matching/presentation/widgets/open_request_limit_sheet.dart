import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/active_concierge_match.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_ui.dart';

/// Figma 9.3 "Open request limit" (node 1015:11374, sheet 819:3023).
///
/// Shown when the customer starts Help me choose while another concierge
/// request is still open. Returns true when they tap "See my requests".
class OpenRequestLimitSheet extends StatelessWidget {
  const OpenRequestLimitSheet({super.key, required this.match});

  final ActiveConciergeMatch match;

  static Future<bool> show(BuildContext context, ActiveConciergeMatch match) async {
    final result = await showConciergeSheet<bool>(
      context: context,
      builder: (_) => OpenRequestLimitSheet(match: match),
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final intro = match.isMatched
        ? 'We work on one request at a time so each gets proper attention. '
              'Your recommendation for this one is ready to look at.'
        : 'We work on one request at a time so each gets proper attention. '
              "You'll hear about this one by tomorrow morning.";

    return ConciergeSheet(
      children: [
        ConciergeSheetHeading(title: 'You already have an open request', intro: intro),
        _OpenRequestItem(
          goal: ConciergeCopy.goalHeadline(match.goal),
          status: ConciergeStatus.label(match.status),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.primary,
              label: 'See my requests',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 20),
            GSWButton(
              size: GSWButtonSize.large,
              variant: GSWButtonVariant.tertiary,
              label: 'Not now',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpenRequestItem extends StatelessWidget {
  const _OpenRequestItem({required this.goal, required this.status});

  final String goal;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              goal.isEmpty ? 'Your trainer request' : goal,
              style: GSWTextStyles.bodyLarge.copyWith(
                color: GSWColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConciergeStatusChip(label: status),
        ],
      ),
    );
  }
}
