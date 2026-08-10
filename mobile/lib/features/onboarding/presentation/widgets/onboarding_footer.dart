import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';

class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'No account needed  ·  No payment now  ·  We reply on WhatsApp',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }
}
