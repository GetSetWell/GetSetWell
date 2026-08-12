import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_language_pill.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_row.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.name,
    required this.service,
    required this.location,
    required this.price,
    required this.languages,
    this.imageUrl,
  });

  final String name;
  final String service;
  final String location;
  final double price;
  final List<String> languages;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GSWColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(GSWRadius.md),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trainer image
          _buildTrainerImage(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNameAndPrice(context),

                const SizedBox(height: 12),

                _buildLocation(context),

                const SizedBox(height: 12),

                const TrainerVerificationRow(),

                const SizedBox(height: 12),

                _buildLanguages(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameAndPrice(BuildContext context) {
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

  Widget _buildLocation(BuildContext context) {
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

  Widget _buildLanguages() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: languages.map((language) => TrainerLanguagePill(label: language)).toList(),
    );
  }

  Widget _buildTrainerImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(GSWRadius.md),
        topRight: Radius.circular(GSWRadius.md),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,

                // Keeps more of the trainer's head visible.
                alignment: Alignment.topCenter,

                errorBuilder: (context, error, stackTrace) {
                  return Container(color: GSWColors.surfacePrimary);
                },
              )
            else
              Container(color: GSWColors.surfacePrimary),

            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.50, 1.0],
                    colors: [Colors.transparent, GSWColors.backgroundSecondary],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
