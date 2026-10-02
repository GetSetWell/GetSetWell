import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/gsw_colors.dart';
import '../../theme/gsw_typography.dart';

// =============================================================================
// TEXT FIELD SIZE
// =============================================================================

enum GSWTextFieldSize { large, medium }

// =============================================================================
// TEXT FIELD STATE
// =============================================================================

enum GSWTextFieldState { defaultState, focused, complete, error, disabled }

// =============================================================================
// GSW TEXT FIELD
// =============================================================================

class GSWTextField extends StatefulWidget {
  const GSWTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.helpingText,
    this.errorText,
    this.leadingIcon,
    this.trailingIcon,
    this.onTrailingTap,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onComplete,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.size = GSWTextFieldSize.large,
  });

  final TextEditingController controller;

  final String? label;
  final String? hintText;
  final String? helpingText;
  final String? errorText;

  /// SVG asset paths
  final String? leadingIcon;
  final String? trailingIcon;

  final VoidCallback? onTrailingTap;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onComplete;

  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final VoidCallback? onTap;

  final GSWTextFieldSize size;

  @override
  State<GSWTextField> createState() => _GSWTextFieldState();
}

// STATE
class _GSWTextFieldState extends State<GSWTextField> {
  late final FocusNode _focusNode;

  bool _hasFocus = false;

  bool get _hasValue => widget.controller.text.trim().isNotEmpty;

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.trim().isNotEmpty;

  // CURRENT STATE
  GSWTextFieldState get _state {
    if (!widget.enabled) {
      return GSWTextFieldState.disabled;
    }

    if (_hasError) {
      return GSWTextFieldState.error;
    }

    if (_hasFocus) {
      return GSWTextFieldState.focused;
    }

    if (_hasValue) {
      return GSWTextFieldState.complete;
    }

    return GSWTextFieldState.defaultState;
  }

  // LIFECYCLE
  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final hadFocus = _hasFocus;

    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });

    // Focused → tap outside / keyboard done
    if (hadFocus && !_hasFocus && _hasValue) {
      widget.onComplete?.call(widget.controller.text.trim());
    }
  }

  void _removeFocus() {
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();

    super.dispose();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------------------
        // LABEL
        // ---------------------------------------------------------------------
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GSWTextStyles.labelMedium.copyWith(color: _labelColor),
          ),

          const SizedBox(height: 8),
        ],

        // ---------------------------------------------------------------------
        // FIELD
        // ---------------------------------------------------------------------
        SizedBox(
          height: _height,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,

            enabled: widget.enabled,

            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            readOnly: widget.readOnly,
            showCursor: widget.readOnly ? false : null,
            enableInteractiveSelection: !widget.readOnly,
            onTap: widget.onTap,
            obscureText: widget.obscureText,

            cursorColor: _cursorColor,

            style: GSWTextStyles.bodyLarge.copyWith(color: _textColor),

            onChanged: (value) {
              setState(() {});

              widget.onChanged?.call(value);
            },

            // Clicking anywhere outside removes focus and the cursor.
            onTapOutside: (_) {
              _removeFocus();
            },

            // Keyboard Done also removes focus.
            onEditingComplete: () {
              _removeFocus();
            },

            decoration: InputDecoration(
              hintText: widget.hintText,

              hintStyle: GSWTextStyles.bodyLarge.copyWith(color: _hintColor),

              filled: true,
              fillColor: _backgroundColor,

              isDense: true,

              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _verticalPadding,
              ),

              // ---------------------------------------------------------------
              // LEADING ICON
              // ---------------------------------------------------------------
              prefixIcon: widget.leadingIcon == null
                  ? null
                  : _buildLeadingIcon(),

              prefixIconConstraints: const BoxConstraints(minWidth: 48),

              // ---------------------------------------------------------------
              // TRAILING ICON
              // ---------------------------------------------------------------
              suffixIcon: widget.trailingIcon == null
                  ? null
                  : _buildTrailingIcon(),

              suffixIconConstraints: const BoxConstraints(minWidth: 48),

              // ---------------------------------------------------------------
              // BORDERS
              // ---------------------------------------------------------------
              enabledBorder: _border,
              focusedBorder: _border,
              disabledBorder: _border,
              errorBorder: _border,
              focusedErrorBorder: _border,
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // HELPING / ERROR TEXT
        // ---------------------------------------------------------------------
        if (_supportingText != null) ...[
          const SizedBox(height: 8),

          Text(
            _supportingText!,
            style: GSWTextStyles.bodySmall.copyWith(
              color: _supportingTextColor,
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // SIZE
  // ===========================================================================

  double get _height {
    switch (widget.size) {
      case GSWTextFieldSize.large:
        return 48;

      case GSWTextFieldSize.medium:
        return 44;
    }
  }

  double get _verticalPadding {
    switch (widget.size) {
      case GSWTextFieldSize.large:
        return 13;

      case GSWTextFieldSize.medium:
        return 11;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case GSWTextFieldSize.large:
        return 20;

      case GSWTextFieldSize.medium:
        return 18;
    }
  }

  // ===========================================================================
  // ICONS
  // ===========================================================================

  Widget _buildLeadingIcon() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 10),
      child: SvgPicture.asset(
        widget.leadingIcon!,
        width: _iconSize,
        height: _iconSize,
        colorFilter: ColorFilter.mode(_leadingIconColor, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildTrailingIcon() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTrailingTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SvgPicture.asset(
          widget.trailingIcon!,
          width: _iconSize,
          height: _iconSize,
          colorFilter: ColorFilter.mode(_trailingIconColor, BlendMode.srcIn),
        ),
      ),
    );
  }

  // ===========================================================================
  // LABEL COLOR
  // ===========================================================================

  Color get _labelColor {
    switch (_state) {
      case GSWTextFieldState.disabled:
        return GSWColors.textTertiary;

      case GSWTextFieldState.defaultState:
      case GSWTextFieldState.focused:
      case GSWTextFieldState.complete:
      case GSWTextFieldState.error:
        return GSWColors.textSecondary;
    }
  }

  // ===========================================================================
  // TEXT COLOR
  // ===========================================================================

  Color get _textColor {
    switch (_state) {
      case GSWTextFieldState.disabled:
        return GSWColors.textTertiary;

      case GSWTextFieldState.defaultState:
      case GSWTextFieldState.focused:
      case GSWTextFieldState.complete:
      case GSWTextFieldState.error:
        return GSWColors.textPrimary;
    }
  }

  // ===========================================================================
  // HINT COLOR
  // ===========================================================================

  Color get _hintColor {
    switch (_state) {
      case GSWTextFieldState.disabled:
        return GSWColors.textTertiary;

      case GSWTextFieldState.defaultState:
      case GSWTextFieldState.focused:
      case GSWTextFieldState.complete:
      case GSWTextFieldState.error:
        return GSWColors.textSecondary;
    }
  }

  // ===========================================================================
  // BACKGROUND COLOR
  // ===========================================================================

  Color get _backgroundColor {
    switch (_state) {
      case GSWTextFieldState.disabled:
        return GSWColors.surfaceElevated;

      case GSWTextFieldState.defaultState:
      case GSWTextFieldState.focused:
      case GSWTextFieldState.complete:
      case GSWTextFieldState.error:
        return GSWColors.surfacePrimary;
    }
  }

  // ===========================================================================
  // BORDER
  // ===========================================================================

  OutlineInputBorder get _border {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _borderColor, width: 1),
    );
  }

  Color get _borderColor {
    switch (_state) {
      case GSWTextFieldState.focused:
        return GSWColors.primary;

      case GSWTextFieldState.error:
        return GSWColors.error;

      case GSWTextFieldState.disabled:
        return GSWColors.borderDisabled;

      case GSWTextFieldState.complete:
      case GSWTextFieldState.defaultState:
        return GSWColors.borderSecondary;
    }
  }

  // ===========================================================================
  // LEADING ICON COLOR
  // ===========================================================================

  Color get _leadingIconColor {
    switch (_state) {
      case GSWTextFieldState.disabled:
        return GSWColors.textTertiary;

      case GSWTextFieldState.defaultState:
      case GSWTextFieldState.focused:
      case GSWTextFieldState.complete:
      case GSWTextFieldState.error:
        return GSWColors.iconSecondary;
    }
  }

  // ===========================================================================
  // TRAILING ICON COLOR
  // ===========================================================================

  Color get _trailingIconColor {
    switch (_state) {
      case GSWTextFieldState.error:
        return GSWColors.error;

      case GSWTextFieldState.disabled:
        return GSWColors.textTertiary;

      case GSWTextFieldState.defaultState:
      case GSWTextFieldState.focused:
      case GSWTextFieldState.complete:
        return GSWColors.iconSecondary;
    }
  }

  // ===========================================================================
  // CURSOR
  // ===========================================================================

  Color get _cursorColor {
    if (_hasError) {
      return GSWColors.error;
    }

    return GSWColors.primary;
  }

  // ===========================================================================
  // SUPPORTING TEXT
  // ===========================================================================

  String? get _supportingText {
    if (_hasError) {
      return widget.errorText;
    }

    return widget.helpingText;
  }

  Color get _supportingTextColor {
    if (_hasError) {
      return GSWColors.error;
    }

    if (!widget.enabled) {
      return GSWColors.textTertiary;
    }

    return GSWColors.textSecondary;
  }
}
