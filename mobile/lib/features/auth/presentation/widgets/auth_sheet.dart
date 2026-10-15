import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

/// Scrim #00050D at 72% (shared sheet spec).
const Color authSheetScrim = Color(0xB800050D);

/// Shows a GetSetWell bottom sheet that the user must answer with a button.
/// Tapping the scrim or dragging does not close it, so the sign-in flow can
/// never be left half finished behind a dismissed sheet.
Future<T?> showAuthSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: authSheetScrim,
    builder: (sheetContext) {
      return PopScope(canPop: false, child: builder(sheetContext));
    },
  );
}

/// Sheet body: 28px grabber zone, 16px sides, 28px bottom plus safe area,
/// heading Outfit Bold 24/30, intro Regular 14/20 secondary.
class AuthSheet extends StatelessWidget {
  const AuthSheet({
    super.key,
    required this.title,
    required this.intro,
    required this.children,
    this.titleGap = 8,
    this.childGap = 20,
  });

  final String title;
  final String intro;

  /// Content below the heading block, separated by [childGap].
  final List<Widget> children;

  final double titleGap;
  final double childGap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final spaced = <Widget>[];

    for (var index = 0; index < children.length; index++) {
      spaced.add(SizedBox(height: childGap));
      spaced.add(children[index]);
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + media.padding.bottom),
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
              title,
              style: GSWTextStyles.titleLarge.copyWith(
                color: GSWColors.textPrimary,
                height: 30 / 24,
              ),
            ),

            SizedBox(height: titleGap),

            Text(
              intro,
              style: GSWTextStyles.bodyMedium.copyWith(
                color: GSWColors.textSecondary,
                height: 20 / 14,
              ),
            ),

            ...spaced,
          ],
        ),
      ),
    );
  }
}

/// Small grey status chip used on request rows.
class AuthStatusChip extends StatelessWidget {
  const AuthStatusChip({super.key, required this.label, this.fontSize = 11, this.outlined = false});

  final String label;
  final double fontSize;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(GSWRadius.full),
        border: outlined ? Border.all(color: GSWColors.surfaceInteractive) : null,
      ),
      child: Text(
        label,
        style: GSWTextStyles.labelSmall.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: (fontSize <= 11 ? 12 : 16) / fontSize,
          color: outlined ? GSWColors.textSecondary : GSWColors.textPrimary,
        ),
      ),
    );
  }
}
