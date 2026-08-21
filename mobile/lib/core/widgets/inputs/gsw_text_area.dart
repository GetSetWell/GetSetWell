import 'package:flutter/material.dart';

import '../../theme/gsw_colors.dart';
import '../../theme/gsw_typography.dart';

// =============================================================================
// TEXT AREA SIZE
// =============================================================================

enum GSWTextAreaSize { large, medium }

// =============================================================================
// TEXT AREA STATE
// =============================================================================

enum GSWTextAreaState { defaultState, focused, complete, error, disabled }

// =============================================================================
// GSW TEXT AREA
// =============================================================================

class GSWTextArea extends StatefulWidget {
  const GSWTextArea({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.helpingText,
    this.errorText,
    this.maxLength = 250,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.newline,
    this.onChanged,
    this.onComplete,
    this.enabled = true,
    this.size = GSWTextAreaSize.large,
  });

  final TextEditingController controller;

  final String? label;
  final String? hintText;

  /// Normal supporting text shown below the field.
  final String? helpingText;

  /// Passing a non-empty errorText forces the error state.
  final String? errorText;

  /// Character counter limit.
  ///
  /// The field intentionally allows typing beyond this value so
  /// states such as 300/250 can be shown and validated.
  final int maxLength;

  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onComplete;

  final bool enabled;

  final GSWTextAreaSize size;

  @override
  State<GSWTextArea> createState() => _GSWTextAreaState();
}

// =============================================================================
// STATE
// =============================================================================

class _GSWTextAreaState extends State<GSWTextArea> {
  late final FocusNode _focusNode;

  bool _hasFocus = false;

  bool get _hasValue => widget.controller.text.trim().isNotEmpty;

  int get _characterCount => widget.controller.text.length;

  bool get _isOverLimit => _characterCount > widget.maxLength;

  bool get _hasExplicitError => widget.errorText != null && widget.errorText!.trim().isNotEmpty;

  bool get _hasError => _hasExplicitError || _isOverLimit;

  // ===========================================================================
  // CURRENT STATE
  // ===========================================================================

  GSWTextAreaState get _state {
    if (!widget.enabled) {
      return GSWTextAreaState.disabled;
    }

    if (_hasError) {
      return GSWTextAreaState.error;
    }

    if (_hasFocus) {
      return GSWTextAreaState.focused;
    }

    if (_hasValue) {
      return GSWTextAreaState.complete;
    }

    return GSWTextAreaState.defaultState;
  }

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);

    widget.controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    final hadFocus = _hasFocus;

    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });

    // Focused → unfocused with content = complete state.
    if (hadFocus && !_hasFocus && _hasValue) {
      widget.onComplete?.call(widget.controller.text.trim());
    }
  }

  void _removeFocus() {
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);

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
          Text(widget.label!, style: GSWTextStyles.labelMedium.copyWith(color: _labelColor)),

          const SizedBox(height: 8),
        ],

        // ---------------------------------------------------------------------
        // TEXT AREA
        // ---------------------------------------------------------------------
        SizedBox(
          height: _height,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,

            enabled: widget.enabled,

            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,

            expands: true,
            minLines: null,
            maxLines: null,

            textAlignVertical: TextAlignVertical.top,

            cursorColor: _cursorColor,

            style: GSWTextStyles.bodyLarge.copyWith(color: _textColor),

            onChanged: (value) {
              widget.onChanged?.call(value);
            },

            // Tapping outside removes cursor + keyboard.
            onTapOutside: (_) {
              _removeFocus();
            },

            decoration: InputDecoration(
              hintText: widget.hintText,

              hintStyle: GSWTextStyles.bodyLarge.copyWith(color: _hintColor),

              filled: true,
              fillColor: _backgroundColor,

              isDense: true,

              contentPadding: const EdgeInsets.all(16),

              enabledBorder: _border,
              focusedBorder: _border,
              disabledBorder: _border,
              errorBorder: _border,
              focusedErrorBorder: _border,
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // HELPING TEXT + CHARACTER COUNTER
        // ---------------------------------------------------------------------
        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _supportingText == null
                  ? const SizedBox.shrink()
                  : Text(
                      _supportingText!,
                      style: GSWTextStyles.bodySmall.copyWith(color: _supportingTextColor),
                    ),
            ),

            const SizedBox(width: 12),

            Text(
              '$_characterCount/${widget.maxLength}',
              style: GSWTextStyles.bodySmall.copyWith(color: _counterColor),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SIZE
  // ===========================================================================

  double get _height {
    switch (widget.size) {
      case GSWTextAreaSize.large:
        return 120;

      case GSWTextAreaSize.medium:
        return 80;
    }
  }

  // ===========================================================================
  // LABEL
  // ===========================================================================

  Color get _labelColor {
    switch (_state) {
      case GSWTextAreaState.disabled:
        return GSWColors.textTertiary;

      case GSWTextAreaState.defaultState:
      case GSWTextAreaState.focused:
      case GSWTextAreaState.complete:
      case GSWTextAreaState.error:
        return GSWColors.textSecondary;
    }
  }

  // ===========================================================================
  // TEXT
  // ===========================================================================

  Color get _textColor {
    switch (_state) {
      case GSWTextAreaState.disabled:
        return GSWColors.textTertiary;

      case GSWTextAreaState.error:
        return _isOverLimit ? GSWColors.error : GSWColors.textPrimary;

      case GSWTextAreaState.defaultState:
      case GSWTextAreaState.focused:
      case GSWTextAreaState.complete:
        return GSWColors.textPrimary;
    }
  }

  // ===========================================================================
  // HINT
  // ===========================================================================

  Color get _hintColor {
    switch (_state) {
      case GSWTextAreaState.disabled:
        return GSWColors.textTertiary;

      case GSWTextAreaState.defaultState:
      case GSWTextAreaState.focused:
      case GSWTextAreaState.complete:
      case GSWTextAreaState.error:
        return GSWColors.textSecondary;
    }
  }

  // ===========================================================================
  // BACKGROUND
  // ===========================================================================

  Color get _backgroundColor {
    switch (_state) {
      case GSWTextAreaState.disabled:
        return GSWColors.surfaceElevated;

      case GSWTextAreaState.defaultState:
      case GSWTextAreaState.focused:
      case GSWTextAreaState.complete:
      case GSWTextAreaState.error:
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
      case GSWTextAreaState.focused:
        return GSWColors.primary;

      case GSWTextAreaState.error:
        return GSWColors.error;

      case GSWTextAreaState.disabled:
        return GSWColors.borderDisabled;

      case GSWTextAreaState.complete:
        return GSWColors.borderSecondary;

      case GSWTextAreaState.defaultState:
        return GSWColors.borderSecondary;
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
    if (_hasExplicitError) {
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

  // ===========================================================================
  // COUNTER
  // ===========================================================================

  Color get _counterColor {
    if (_hasError) {
      return GSWColors.error;
    }

    if (!widget.enabled) {
      return GSWColors.textTertiary;
    }

    return GSWColors.textSecondary;
  }
}
