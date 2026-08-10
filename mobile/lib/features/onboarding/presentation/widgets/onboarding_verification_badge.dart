import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/gsw_constants.dart';
import '../../../../core/constants/gsw_icons.dart';
import '../../../../core/theme/gsw_radius.dart';
import '../../../../core/theme/gsw_spacing.dart';

class VerifiedTrainerBadge extends StatelessWidget {
  const VerifiedTrainerBadge({super.key});

  static const _lime = Color(0xFFDAE64B);
  static const _background = Color(0xE6000D1B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GSWSpacing.xxs, vertical: GSWSpacing.xxs),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(GSWRadius.md),
        border: Border.all(color: _lime.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            GSWIcons.verified,
            width: GSWSizes.verifiedlogo,
            height: GSWSizes.verifiedlogo,
            colorFilter: const ColorFilter.mode(Color(0xFFDAE64B), BlendMode.srcIn),
          ),
          SizedBox(width: GSWSpacing.xxs),
          Text(
            'Personally verified\ntrainers in Dubai',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
