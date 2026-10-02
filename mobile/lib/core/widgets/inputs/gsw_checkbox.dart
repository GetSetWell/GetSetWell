import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';

import '../../theme/gsw_colors.dart';

// =============================================================================
// GSW CHECKBOX
// =============================================================================

class GSWCheckbox extends StatefulWidget {
  const GSWCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = 24,
    this.iconSize = 14,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  final bool enabled;

  /// Visible checkbox size.
  final double size;
  final double iconSize;
  @override
  State<GSWCheckbox> createState() => _GSWCheckboxState();
}

// =============================================================================
// STATE
// =============================================================================

class _GSWCheckboxState extends State<GSWCheckbox> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isEnabled => widget.enabled && widget.onChanged != null;

  void _toggle() {
    if (!_isEnabled) return;

    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: widget.value,
      enabled: _isEnabled,
      child: FocusableActionDetector(
        enabled: _isEnabled,
        mouseCursor: _isEnabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) {
          setState(() {
            _isFocused = value;
          });
        },
        onShowHoverHighlight: (value) {
          setState(() {
            _isHovered = value;
          });
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          onTapDown: _isEnabled
              ? (_) {
                  setState(() {
                    _isPressed = true;
                  });
                }
              : null,
          onTapUp: _isEnabled
              ? (_) {
                  setState(() {
                    _isPressed = false;
                  });
                }
              : null,
          onTapCancel: _isEnabled
              ? () {
                  setState(() {
                    _isPressed = false;
                  });
                }
              : null,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _borderColor, width: _borderWidth),
                  boxShadow: _focusShadow,
                ),
                child: widget.value
                    ? SvgPicture.asset(
                        GSWIcons.check,
                        height: widget.iconSize,
                        width: widget.iconSize,
                        colorFilter: (!_isEnabled)
                            ? const ColorFilter.mode(
                                GSWColors.textTertiary,
                                BlendMode.srcIn,
                              )
                            : const ColorFilter.mode(
                                GSWColors.textInverse,
                                BlendMode.srcIn,
                              ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BACKGROUND
  // ===========================================================================

  Color get _backgroundColor {
    // Disabled
    if (!_isEnabled) {
      if (widget.value) {
        return GSWColors.surfaceInteractive;
      }

      return GSWColors.surfacePrimary;
    }

    // Checked
    if (widget.value) {
      if (_isPressed) {
        return GSWColors.primary.withValues(alpha: 0.85);
      }

      if (_isHovered) {
        return GSWColors.primary.withValues(alpha: 0.92);
      }

      return GSWColors.primary;
    }

    // Unchecked
    if (_isPressed || _isHovered) {
      return GSWColors.surfaceInteractive;
    }

    return GSWColors.surfacePrimary;
  }

  // ===========================================================================
  // BORDER
  // ===========================================================================

  Color get _borderColor {
    if (!_isEnabled) {
      return GSWColors.borderDisabled;
    }

    if (widget.value) {
      return GSWColors.primary;
    }

    if (_isFocused) {
      return GSWColors.primary;
    }

    return GSWColors.borderSecondary;
  }

  double get _borderWidth {
    if (_isFocused && _isEnabled) {
      return 2;
    }

    return 1;
  }

  // ===========================================================================
  // FOCUS
  // ===========================================================================

  List<BoxShadow>? get _focusShadow {
    if (!_isFocused || !_isEnabled) {
      return null;
    }

    return [
      BoxShadow(
        color: GSWColors.primary.withValues(alpha: 0.18),
        blurRadius: 0,
        spreadRadius: 3,
      ),
    ];
  }
}
