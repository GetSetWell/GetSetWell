import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';

import '../../../../core/theme/gsw_colors.dart';

/// Name, primary service and "from" rate with the total including the 5% fee.
///
/// Figma (8.1 card): name Bebas 30/30, service Outfit 14/20, rate Bebas 30/30
/// accent, "/session" 12/16 and "AED 336 total" 11/15 in Text/Secondary.
/// The profile (8.4) uses the same block one step larger ([large]).
class TrainerNameAndPrice extends StatelessWidget {
  const TrainerNameAndPrice({
    super.key,
    required this.name,
    required this.service,
    required this.price,
    this.large = false,
  });

  final String name;
  final String service;

  /// Session rate before the fee. Null when the trainer has no rate yet.
  final double? price;

  final bool large;

  @override
  Widget build(BuildContext context) {
    final nameSize = large ? 34.0 : 30.0;

    final nameStyle = GSWTextStyles.headingLarge.copyWith(
      fontSize: nameSize,
      height: 1,
      color: GSWColors.textPrimary,
    );

    final priceStyle = GSWTextStyles.headingLarge.copyWith(
      fontSize: nameSize,
      height: 1,
      color: GSWColors.textAccent,
    );

    final secondaryStyle = GSWTextStyles.bodySmall.copyWith(
      color: GSWColors.textSecondary,
      height: 16 / 12,
    );

    final totalStyle = GSWTextStyles.bodyExtraSmall.copyWith(
      color: GSWColors.textSecondary,
      height: 15 / 11,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),

              if (service.trim().isNotEmpty) ...[
                const SizedBox(height: 4),

                Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSWTextStyles.bodyMedium.copyWith(
                    color: GSWColors.textPrimary,
                    height: 20 / 14,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (price != null) ...[
          const SizedBox(width: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(GSWMoney.aed(price), style: priceStyle),

              Text('/session', style: secondaryStyle),

              Text('${GSWMoney.aed(GSWMoney.totalWithFee(price!))} total', style: totalStyle),
            ],
          ),
        ],
      ],
    );
  }
}

class TrainerLocation extends StatelessWidget {
  const TrainerLocation({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          GSWIcons.location,
          width: GSWSizes.icon,
          height: GSWSizes.icon,
          colorFilter: const ColorFilter.mode(GSWColors.iconSecondary, BlendMode.srcIn),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }
}
