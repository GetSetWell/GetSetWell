import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Shared bottom-sheet chrome for the trainers feature, per the FINAL Figma
/// sheet spec: Background/Primary fill, 28px top corners, a 40x4 grabber in a
/// 28px zone, content 16px sides, heading Outfit Bold 24.
/// Scrim is the shared GSWColors.scrim (#00050D at 72%).
class TrainerSheetFrame {
  TrainerSheetFrame._();

  static const Color scrim = GSWColors.scrim;

  /// Figma full-height sheets start 54px below the top of an 844 frame.
  static const double fullHeightFactor = 790 / 844;

  static Future<T?> showFullHeight<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: scrim,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: fullHeightFactor,
          alignment: Alignment.bottomCenter,
          child: GSWSheetDragDismiss(
            child: Container(
              decoration: const BoxDecoration(
                color: GSWColors.backgroundPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
              ),
              clipBehavior: Clip.antiAlias,
              child: builder(sheetContext),
            ),
          ),
        );
      },
    );
  }
}

/// 28px zone with a centred 40x4 grabber.
class TrainerSheetGrabber extends StatelessWidget {
  const TrainerSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: double.infinity,
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
    );
  }
}

/// Sticky bottom bar: 16px padding around a full-width large button,
/// plus the device safe area.
class TrainerSheetBottomBar extends StatelessWidget {
  const TrainerSheetBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      width: double.infinity,
      color: GSWColors.backgroundPrimary,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + bottomInset),
      child: child,
    );
  }
}

/// Heading text used by trainer sheets.
TextStyle trainerSheetHeadingStyle() {
  return GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24);
}
