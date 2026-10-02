import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/features/trainers/domain/models/trainer_verification_check.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_language_pill.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_row.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_sheet.dart';

import 'trainer_summary.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({
    super.key,
    required this.name,
    required this.service,
    required this.location,
    required this.price,
    required this.languages,
    this.imageUrl,
    required this.verificationChecks,
    required this.onTap,
  });

  final String name;
  final String service;
  final String location;
  final double price;
  final List<String> languages;
  final String? imageUrl;
  final List<TrainerVerificationCheck> verificationChecks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
                  TrainerNameAndPrice(
                    name: name,
                    service: service,
                    price: price,
                  ),

                  const SizedBox(height: 12),

                  TrainerLocation(location: location),

                  const SizedBox(height: 12),

                  TrainerVerificationRow(
                    onTap: () {
                      TrainerVerificationSheet.show(
                        context,
                        trainerName: name,
                        items: verificationChecks,
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildLanguages(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguages() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: languages
          .map((language) => TrainerLanguagePill(label: language))
          .toList(),
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
