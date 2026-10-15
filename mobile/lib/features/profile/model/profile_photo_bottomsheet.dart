import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';

import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// 12.2b Profile photo options (Figma 1046:3337). Bottom sheet per the shared
/// sheet spec: 28px grabber zone, 16px sides, 28px bottom, 20px gap.
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
      barrierColor: GSWColors.scrim,
      enableDrag: false,
      builder: (_) => GSWSheetDragDismiss(
        child: Builder(builder: (context) {
        return ProfilePhotoSheet(
          onTakePhoto: onTakePhoto,
          onChooseFromLibrary: onChooseFromLibrary,
          onRemovePhoto: onRemovePhoto,
          hasPhoto: hasPhoto,
        );
      }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 28,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GSWColors.surfaceInteractive,
                    borderRadius: BorderRadius.circular(GSWRadius.full),
                  ),
                ),
              ),
            ),

            Text(
              'Profile photo',
              style: GSWTextStyles.titleLarge.copyWith(height: 1, color: GSWColors.textPrimary),
            ),

            const SizedBox(height: 8),

            Text(
              'Use a clear photo of your face, on its own. Only your trainer and GetSetWell see it.',
              style: GSWTextStyles.bodyMedium.copyWith(
                height: 20 / 14,
                color: GSWColors.textSecondary,
              ),
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
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
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
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
    return const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive);
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GSWTextStyles.bodyLarge.copyWith(
                      height: 22 / 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: GSWTextStyles.bodyMedium.copyWith(
                      fontSize: 13,
                      height: 18 / 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
