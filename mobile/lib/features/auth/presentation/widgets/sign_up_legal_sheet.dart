import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';

import 'auth_sheet.dart';

/// 12.5c Terms during sign-up (Figma 1070:3618): the legal document opens as
/// a tall sheet over the sign-up screen instead of a new page, so the person
/// never loses their place. Reading it never signs anyone up.
///
/// [body] is the document content only (short version card, search,
/// sections), without its own app bar or title.
Future<void> showSignUpLegalSheet({
  required BuildContext context,
  required String title,
  required String version,
  required Widget body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: authSheetScrim,
    builder: (sheetContext) {
      return GSWSheetDragDismiss(
        child: SignUpLegalSheet(title: title, version: version, body: body),
      );
    },
  );
}

class SignUpLegalSheet extends StatelessWidget {
  const SignUpLegalSheet({
    super.key,
    required this.title,
    required this.version,
    required this.body,
  });

  final String title;
  final String version;
  final Widget body;

  /// Gap between the status bar and the top of the sheet (54 - 42 in Figma).
  static const double _topGap = 12;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final bottomInset = media.padding.bottom > 0 ? media.padding.bottom : 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxHeight - _topGap,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grabber: 40 x 4 in a 28px zone.
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

              _buildHeader(context),

              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: body,
                  ),
                ),
              ),

              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: GSWColors.surfaceInteractive)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GSWButton(
                      size: GSWButtonSize.large,
                      label: 'Done',
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Reading this doesn't sign you up. You agree on the Your details screen.",
                      textAlign: TextAlign.center,
                      style: GSWTextStyles.bodySmall.copyWith(
                        height: 16 / 12,
                        color: GSWColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GSWTextStyles.titleLarge.copyWith(
                    color: GSWColors.textPrimary,
                    height: 30 / 24,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  version,
                  style: GSWTextStyles.bodySmall.copyWith(
                    height: 16 / 12,
                    color: GSWColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Semantics(
            button: true,
            label: 'Close',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(side: BorderSide(color: GSWColors.surfaceInteractive)),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SvgPicture.asset(
                      GSWIcons.close,
                      width: 12,
                      height: 12,
                      colorFilter: const ColorFilter.mode(GSWColors.iconPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
