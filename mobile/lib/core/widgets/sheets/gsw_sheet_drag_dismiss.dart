import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lets a bottom sheet be closed by dragging down anywhere on it, not just
/// the grabber.
///
/// - On parts that do not scroll, a downward drag moves the sheet with the
///   finger.
/// - Inside a scrolling list, the list scrolls as normal; once it is at the
///   top, pulling further down moves the sheet instead.
/// - On release the sheet closes if it was pulled down a quarter of its height
///   or flicked down; otherwise it springs back.
///
/// Wrap the sheet body with it and open the sheet with `enableDrag: false`,
/// so the built-in grabber drag does not compete with this one. Closing goes
/// through [Navigator.maybePop], so a sheet that blocks closing with
/// PopScope simply springs back.
class GSWSheetDragDismiss extends StatefulWidget {
  const GSWSheetDragDismiss({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// False for sheets the person must answer with a button.
  final bool enabled;

  @override
  State<GSWSheetDragDismiss> createState() => _GSWSheetDragDismissState();
}

class _GSWSheetDragDismissState extends State<GSWSheetDragDismiss>
    with SingleTickerProviderStateMixin {
  /// Fraction of the sheet height past which a release closes it.
  static const double _closeFraction = 0.25;

  /// Downward fling speed (logical px per second) that closes it.
  static const double _closeVelocity = 700;

  /// Current downward offset of the sheet, in logical pixels.
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);

  bool _closing = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  double get _height {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.height > 0) return box.size.height;
    return MediaQuery.sizeOf(context).height / 2;
  }

  void _dragBy(double delta) {
    if (!widget.enabled || _closing) return;
    _offset.value = math.max(0, _offset.value + delta);
  }

  Future<void> _release(double velocity) async {
    if (!widget.enabled || _closing) return;

    final pulled = _offset.value;
    if (pulled <= 0) return;

    final shouldClose =
        velocity > _closeVelocity || (pulled > _height * _closeFraction && velocity > -300);

    if (shouldClose) {
      // maybePop also returns true when PopScope blocks the pop, so check
      // first whether this route will actually close.
      final blocked = ModalRoute.of(context)?.popDisposition == RoutePopDisposition.doNotPop;
      _closing = true;
      final popped = await Navigator.of(context).maybePop();
      if (!mounted) return;
      if (popped && !blocked) return;
      _closing = false;
    }

    await _offset.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.enabled || _closing || notification.metrics.axis != Axis.vertical) return false;

    if (notification is OverscrollNotification) {
      // The list is already at the top and the finger keeps pulling down.
      if (notification.dragDetails != null && notification.overscroll < 0) {
        _dragBy(-notification.overscroll);
      }
    } else if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
      final delta = notification.scrollDelta ?? 0;
      final metrics = notification.metrics;

      if (metrics.pixels < metrics.minScrollExtent) {
        // Bouncing physics report the pull as a negative scroll instead.
        _dragBy(-delta);
      } else if (_offset.value > 0 && delta > 0) {
        // Finger moving back up while the sheet is pulled down: lift the
        // sheet back into place first.
        _dragBy(-delta);
      }
    } else if (notification is ScrollEndNotification) {
      _release(notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) => _dragBy(details.delta.dy),
      onVerticalDragEnd: (details) => _release(details.velocity.pixelsPerSecond.dy),
      onVerticalDragCancel: () => _release(0),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ScrollConfiguration(
          // Clamping, so a pull at the top is reported as overscroll on iOS
          // too, instead of bouncing the content.
          behavior: ScrollConfiguration.of(context).copyWith(
            physics: const ClampingScrollPhysics(),
            overscroll: false,
          ),
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _offset.value),
              child: child,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
