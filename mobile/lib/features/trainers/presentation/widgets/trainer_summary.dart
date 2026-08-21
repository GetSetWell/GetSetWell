import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';

import '../../../../core/theme/gsw_colors.dart';

class TrainerNameAndPrice extends StatelessWidget {
  const TrainerNameAndPrice({
    super.key,
    required this.name,
    required this.service,
    required this.price,
  });

  final String name;
  final String service;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: GSWColors.textPrimary),
              ),

              const SizedBox(height: 4),

              Text(
                service,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: GSWColors.textPrimary),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'AED ${price.toInt()}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: GSWColors.primary),
            ),

            Text(
              '/session',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary),
            ),
          ],
        ),
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
