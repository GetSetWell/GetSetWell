import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Trainer portrait with a safe fallback.
///
/// Shows the trainer's initials on a surface colour when there is no image,
/// while the image loads, or when the network image fails.
class TrainerPhoto extends StatelessWidget {
  const TrainerPhoto({
    super.key,
    required this.name,
    this.imageUrl,
    this.alignment = Alignment.topCenter,
    this.initialsStyle,
  });

  final String name;
  final String? imageUrl;
  final Alignment alignment;
  final TextStyle? initialsStyle;

  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '';

    final first = parts.first.substring(0, 1);

    if (parts.length == 1) return first.toUpperCase();

    final last = parts.last.substring(0, 1);

    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      return _buildPlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: alignment,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return _buildPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return ColoredBox(
      color: GSWColors.surfaceElevated,
      child: Center(
        child: Text(
          initialsFor(name),
          style:
              initialsStyle ??
              GSWTextStyles.displayMedium.copyWith(color: GSWColors.textTertiary),
        ),
      ),
    );
  }
}
