import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/features/trainers/domain/models/trainer_verification_check.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_language_pill.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_photo.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_row.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_sheet.dart';

import 'trainer_summary.dart';

/// Trainer card from Figma 7.x / 8.1: 200px portrait with a bottom gradient,
/// then name and rate, area, the checked row and language pills.
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

  /// Session rate before the 5% fee. Null hides the price block.
  final double? price;

  final List<String> languages;
  final String? imageUrl;
  final List<TrainerVerificationCheck> verificationChecks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showChecks = TrainerVerificationSheet.hasChecks(verificationChecks);
    final visibleLanguages = languages.where((language) => language.trim().isNotEmpty).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        // The photo is clipped to the card's rounded corners, and the 1px
        // border is painted on top of it, so the corners stay clean.
        decoration: BoxDecoration(
          color: GSWColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(GSWRadius.card),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GSWRadius.card),
          border: Border.all(color: GSWColors.borderDisabled),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTrainerImage(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrainerNameAndPrice(name: name, service: service, price: price),

                  const SizedBox(height: 12),

                  TrainerLocation(location: location),

                  if (showChecks) ...[
                    const SizedBox(height: 12),

                    TrainerVerificationRow(
                      nested: true,
                      onTap: () {
                        TrainerVerificationSheet.show(
                          context,
                          trainerName: name,
                          items: verificationChecks,
                        );
                      },
                    ),
                  ],

                  if (visibleLanguages.isNotEmpty) ...[
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: visibleLanguages
                          .map((language) => TrainerLanguagePill(label: language))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerImage() {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TrainerPhoto(name: name, imageUrl: imageUrl),

          // Figma: transparent to 50% to Surface/Primary, top to bottom.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  GSWColors.surfacePrimary.withValues(alpha: 0),
                  GSWColors.surfacePrimary.withValues(alpha: 0.5),
                  GSWColors.surfacePrimary,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
