import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';

class ProfilePhotoSheet extends StatelessWidget {
  const ProfilePhotoSheet({
    super.key,
    required this.onTakePhoto,
    required this.onChooseFromLibrary,
    required this.onRemovePhoto,
    required this.hasPhoto,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFromLibrary;
  final VoidCallback onRemovePhoto;
  final bool hasPhoto;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onTakePhoto,
    required VoidCallback onChooseFromLibrary,
    required VoidCallback onRemovePhoto,
    required bool hasPhoto,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) {
        return ProfilePhotoSheet(
          onTakePhoto: onTakePhoto,
          onChooseFromLibrary: onChooseFromLibrary,
          onRemovePhoto: onRemovePhoto,
          hasPhoto: hasPhoto,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GSWColors.borderSecondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Profile photo',
                style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
              ),

              const SizedBox(height: 8),

              Text(
                'Use a clear photo of your face, on its own. Only your trainer and GetSetWell see it.',
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),

              const SizedBox(height: 20),

              _ActionCard(
                hasPhoto: hasPhoto,
                onTakePhoto: () {
                  Navigator.of(context).pop();
                  onTakePhoto();
                },
                onChooseFromLibrary: () {
                  Navigator.of(context).pop();
                  onChooseFromLibrary();
                },
                onRemovePhoto: () {
                  Navigator.of(context).pop();
                  onRemovePhoto();
                },
              ),

              const SizedBox(height: 20),

              GSWButton(
                label: 'Cancel',
                variant: GSWButtonVariant.tertiary,
                onPressed: context.pop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.hasPhoto,
    required this.onTakePhoto,
    required this.onChooseFromLibrary,
    required this.onRemovePhoto,
  });

  final bool hasPhoto;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFromLibrary;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.borderSecondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _PhotoActionRow(title: 'Take a photo', subtitle: 'Uses your camera', onTap: onTakePhoto),

          _divider(),

          _PhotoActionRow(
            title: 'Choose from library',
            subtitle: 'Pick one you already have',
            onTap: onChooseFromLibrary,
          ),

          _divider(),

          _PhotoActionRow(
            title: 'Remove photo',
            subtitle: 'Go back to your initial',
            destructive: true,
            enabled: hasPhoto,
            onTap: onRemovePhoto,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: GSWColors.borderSecondary);
  }
}

class _PhotoActionRow extends StatelessWidget {
  const _PhotoActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final titleColor = !enabled
        ? GSWColors.textTertiary
        : destructive
        ? GSWColors.error
        : GSWColors.textPrimary;

    final subtitleColor = enabled ? GSWColors.textSecondary : GSWColors.textTertiary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GSWTextStyles.bodyLarge.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(subtitle, style: GSWTextStyles.bodySmall.copyWith(color: subtitleColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
