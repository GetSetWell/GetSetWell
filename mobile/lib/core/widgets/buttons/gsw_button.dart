import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_sizes.dart';
import 'package:mobile/core/theme/gsw_spacing.dart';

enum GSWButtonVariant { primary, secondary, tertiary, destructive, disabled }

enum GSWButtonSize { large, medium }

class GSWButton extends StatelessWidget {
  const GSWButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GSWButtonVariant.primary,
    this.size = GSWButtonSize.large,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;

  final GSWButtonVariant variant;
  final GSWButtonSize size;

  /// SVG asset paths
  final String? leadingIcon;
  final String? trailingIcon;

  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final bool disabled = variant == GSWButtonVariant.disabled || onPressed == null || isLoading;
    final Color iconColor = disabled ? GSWColors.textTertiary : _defaultIconColor;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: ButtonStyle(
          // -------------------------------------------------------------------
          // TYPOGRAPHY
          // -------------------------------------------------------------------
          textStyle: WidgetStatePropertyAll(_buttonTextStyle(context)),

          // -------------------------------------------------------------------
          // TEXT COLOR
          // -------------------------------------------------------------------
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) => _contentColor(states),
          ),

          // -------------------------------------------------------------------
          // BACKGROUND
          // -------------------------------------------------------------------
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) => _backgroundColor(states),
          ),

          // -------------------------------------------------------------------
          // BORDER
          // -------------------------------------------------------------------
          side: WidgetStateProperty.resolveWith<BorderSide>((states) => _border(states)),

          // -------------------------------------------------------------------
          // INTERACTION OVERLAY
          // -------------------------------------------------------------------
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) => _overlayColor(states)),

          // -------------------------------------------------------------------
          // SIZE / SHAPE
          // -------------------------------------------------------------------
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: _horizontalPadding)),

          minimumSize: WidgetStatePropertyAll(Size(fullWidth ? double.infinity : 0, _height)),

          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),

          elevation: const WidgetStatePropertyAll(0),

          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),

        // ---------------------------------------------------------------------
        // CONTENT
        // ---------------------------------------------------------------------
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: isLoading
              ? _LoadingIndicator(key: const ValueKey('loading'), color: iconColor)
              : _ButtonContent(
                  key: const ValueKey('content'),
                  label: label,
                  leadingIcon: leadingIcon,
                  trailingIcon: trailingIcon,
                  iconColor: iconColor,
                  iconSize: _iconSize,
                  gap: _iconGap,
                ),
        ),
      ),
    );
  }

  Color _backgroundColor(Set<WidgetState> states) {
    if (variant == GSWButtonVariant.disabled) {
      return GSWColors.surfacePrimary;
    }

    if (states.contains(WidgetState.disabled)) {
      switch (variant) {
        case GSWButtonVariant.primary:
        case GSWButtonVariant.secondary:
        case GSWButtonVariant.destructive:
          return GSWColors.surfaceElevated;

        case GSWButtonVariant.tertiary:
          return Colors.transparent;

        case GSWButtonVariant.disabled:
          return GSWColors.surfacePrimary;
      }
    }

    switch (variant) {
      case GSWButtonVariant.primary:
        if (states.contains(WidgetState.pressed)) {
          return GSWColors.primary.withValues(alpha: 0.85);
        }

        if (states.contains(WidgetState.hovered)) {
          return GSWColors.primary.withValues(alpha: 0.92);
        }

        return GSWColors.primary;

      case GSWButtonVariant.destructive:
        if (states.contains(WidgetState.pressed)) {
          return GSWColors.error.withValues(alpha: 0.85);
        }

        if (states.contains(WidgetState.hovered)) {
          return GSWColors.error.withValues(alpha: 0.92);
        }

        return GSWColors.error;

      case GSWButtonVariant.secondary:
        if (states.contains(WidgetState.pressed)) {
          return GSWColors.surfaceElevated.withValues(alpha: 0.75);
        }

        if (states.contains(WidgetState.hovered)) {
          return GSWColors.surfaceInteractive.withValues(alpha: 0.9);
        }

        return GSWColors.surfaceElevated;

      case GSWButtonVariant.tertiary:
        return Colors.transparent;

      case GSWButtonVariant.disabled:
        return GSWColors.surfacePrimary;
    }
  }
  // ===========================================================================
  // TYPOGRAPHY
  // ===========================================================================

  TextStyle _buttonTextStyle(BuildContext context) {
    switch (size) {
      case GSWButtonSize.large:
        return Theme.of(context).textTheme.labelLarge!;

      case GSWButtonSize.medium:
        return Theme.of(context).textTheme.labelLarge!;
    }
  }

  // ===========================================================================
  // SIZE
  // ===========================================================================

  double get _height {
    switch (size) {
      case GSWButtonSize.large:
        return 48;

      case GSWButtonSize.medium:
        return 44;
    }
  }

  double get _horizontalPadding {
    switch (size) {
      case GSWButtonSize.large:
        return GSWSpacing.sm;

      case GSWButtonSize.medium:
        return GSWSpacing.sm;
    }
  }

  double get _iconSize {
    switch (size) {
      case GSWButtonSize.large:
        return GSWSizes.xs;

      case GSWButtonSize.medium:
        return GSWSizes.xs;
    }
  }

  double get _iconGap {
    switch (size) {
      case GSWButtonSize.large:
        return GSWSpacing.xxs;

      case GSWButtonSize.medium:
        return GSWSpacing.xxs;
    }
  }

  // ===========================================================================
  // DEFAULT CONTENT COLOR
  // ===========================================================================
  Color get _defaultContentColor {
    switch (variant) {
      case GSWButtonVariant.primary:
        return GSWColors.textInverse;

      case GSWButtonVariant.secondary:
        return GSWColors.textPrimary;

      case GSWButtonVariant.tertiary:
        return GSWColors.primary;

      case GSWButtonVariant.destructive:
        return GSWColors.textInverse;

      case GSWButtonVariant.disabled:
        return GSWColors.textTertiary;
    }
  }

  // ===========================================================================
  // DEFAULT ICON COLOR
  // ===========================================================================

  Color get _defaultIconColor {
    switch (variant) {
      case GSWButtonVariant.primary:
        return GSWColors.textInverse;

      case GSWButtonVariant.secondary:
        return GSWColors.primary;

      case GSWButtonVariant.tertiary:
        return GSWColors.primary;

      case GSWButtonVariant.destructive:
        return GSWColors.textInverse;

      case GSWButtonVariant.disabled:
        return GSWColors.textTertiary;
    }
  }

  // ===========================================================================
  // TEXT COLOR
  // ===========================================================================

  Color _contentColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return GSWColors.textTertiary; // TERTIARY TEXT = #586169
    }

    return _defaultContentColor;
  }

  // ===========================================================================
  // BORDER
  // ===========================================================================

  BorderSide _border(Set<WidgetState> states) {
    if (variant == GSWButtonVariant.disabled) {
      return const BorderSide(color: GSWColors.borderDisabled, width: 1);
    }

    if (variant != GSWButtonVariant.secondary) {
      return BorderSide.none;
    }

    if (states.contains(WidgetState.disabled)) {
      return const BorderSide(color: GSWColors.borderDisabled, width: 1);
    }

    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: GSWColors.primary, width: 2);
    }

    return const BorderSide(color: GSWColors.borderSecondary, width: 1);
  }
  // ===========================================================================
  // PRESSED / HOVER OVERLAY
  // ===========================================================================

  Color? _overlayColor(Set<WidgetState> states) {
    if (variant == GSWButtonVariant.disabled || states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }

    if (states.contains(WidgetState.pressed)) {
      switch (variant) {
        case GSWButtonVariant.primary:
        case GSWButtonVariant.destructive:
          return GSWColors.surfaceElevated.withValues(alpha: 0.08);

        case GSWButtonVariant.secondary:
        case GSWButtonVariant.tertiary:
          return GSWColors.primary.withValues(alpha: 0.08);

        case GSWButtonVariant.disabled:
          return Colors.transparent;
      }
    }

    if (states.contains(WidgetState.hovered)) {
      return GSWColors.primary.withValues(alpha: 0.04);
    }

    return Colors.transparent;
  }
}

// =============================================================================
// BUTTON CONTENT
// =============================================================================

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    super.key,
    required this.label,
    required this.iconColor,
    required this.iconSize,
    required this.gap,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;

  final String? leadingIcon;
  final String? trailingIcon;

  final Color iconColor;

  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          _GSWButtonIcon(asset: leadingIcon!, size: iconSize, color: iconColor),
          SizedBox(width: gap),
        ],

        // IMPORTANT:
        // No TextStyle is applied here.
        // The Text inherits ButtonStyle.foregroundColor and ButtonStyle.textStyle.
        Text(label),

        if (trailingIcon != null) ...[
          SizedBox(width: gap),
          _GSWButtonIcon(asset: trailingIcon!, size: iconSize, color: iconColor),
        ],
      ],
    );
  }
}

// =============================================================================
// SVG ICON
// =============================================================================

class _GSWButtonIcon extends StatelessWidget {
  const _GSWButtonIcon({required this.asset, required this.size, required this.color});

  final String asset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

// =============================================================================
// LOADING INDICATOR
// =============================================================================

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
