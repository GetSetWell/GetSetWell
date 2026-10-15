import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';

import '../../domain/phone_display.dart';
import 'auth_sheet.dart';

enum AccountSheetAction { primary, secondary }

/// 3.8 Sheet, account already exists. Shown over the verified code screen
/// when Get started finds an existing completed account. It greets rather
/// than warns; "Not you?" covers recycled UAE numbers.
Future<AccountSheetAction> showAccountExistsSheet({
  required BuildContext context,
  String? firstName,
}) async {
  final name = firstName?.trim() ?? '';

  final action = await showAuthSheet<AccountSheetAction>(
    context: context,
    builder: (sheetContext) {
      return AuthSheet(
        title: name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
        intro:
            "This number already has a GetSetWell account, so we've signed you in "
            'instead of creating a second one.',
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GSWButton(
                size: GSWButtonSize.large,
                label: 'Go to Home',
                onPressed: () => Navigator.of(sheetContext).pop(AccountSheetAction.primary),
              ),

              const SizedBox(height: 8),

              GSWButton(
                size: GSWButtonSize.large,
                variant: GSWButtonVariant.tertiary,
                label: 'Not you? Use a different number',
                onPressed: () => Navigator.of(sheetContext).pop(AccountSheetAction.secondary),
              ),
            ],
          ),
        ],
      );
    },
  );

  // The sheet cannot be dismissed without a button, but never leave the
  // caller without an answer: default to the safe, signed-in path.
  return action ?? AccountSheetAction.primary;
}

/// 3.9 Sheet, no account on this number. Shown when "I already have an
/// account" verifies a number that has no completed profile.
Future<AccountSheetAction> showNoAccountSheet({
  required BuildContext context,
  required String phone,
}) async {
  final action = await showAuthSheet<AccountSheetAction>(
    context: context,
    builder: (sheetContext) {
      return AuthSheet(
        title: 'No account on this number yet',
        intro:
            "If you joined with a different number, switch to it. If you're new, "
            'setting up takes one more step.',
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: GSWColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(GSWRadius.card),
              border: Border.all(color: GSWColors.surfaceInteractive),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatPhoneForDisplay(phone),
                  style: GSWTextStyles.labelLarge.copyWith(
                    height: 22 / 16,
                    color: GSWColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Verified just now by SMS',
                  style: GSWTextStyles.bodySmall.copyWith(
                    fontSize: 13,
                    height: 18 / 13,
                    color: GSWColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GSWButton(
                size: GSWButtonSize.large,
                label: 'Create my account',
                onPressed: () => Navigator.of(sheetContext).pop(AccountSheetAction.primary),
              ),

              const SizedBox(height: 12),

              GSWButton(
                size: GSWButtonSize.large,
                variant: GSWButtonVariant.secondary,
                label: 'Use a different number',
                onPressed: () => Navigator.of(sheetContext).pop(AccountSheetAction.secondary),
              ),
            ],
          ),
        ],
      );
    },
  );

  return action ?? AccountSheetAction.primary;
}
