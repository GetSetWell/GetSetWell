import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/features/auth/presentation/widgets/sign_up_legal_sheet.dart';
import 'package:mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:mobile/features/legal/presentation/screens/terms_of_service_screen.dart';

/// "By continuing you agree to our Terms of Service and Privacy Policy."
///
/// Three placements, each matching its Figma frame:
/// - [LegalAgreementText.new] phone entry (3.1): left aligned, 12/16 tertiary.
/// - [LegalAgreementText.welcome] Welcome (1.2): centred, 12/12, "Terms".
/// - [LegalAgreementText.signUpConsent] Your details checkbox label (3.5):
///   "I'm 18 or over and I agree to the ...", 12/16 secondary.
///
/// Reading the documents never signs anyone up; agreement is recorded by the
/// checkbox on Your details.
class LegalAgreementText extends StatefulWidget {
  const LegalAgreementText({super.key})
    : prefix = 'By continuing you agree to our ',
      termsLabel = 'Terms of Service',
      textAlign = TextAlign.start,
      color = GSWColors.textTertiary,
      lineHeight = 16;

  const LegalAgreementText.welcome({super.key})
    : prefix = 'By continuing you agree to our ',
      termsLabel = 'Terms',
      textAlign = TextAlign.center,
      color = GSWColors.textTertiary,
      lineHeight = 12;

  const LegalAgreementText.signUpConsent({super.key})
    : prefix = "I'm 18 or over and I agree to the ",
      termsLabel = 'Terms of Service',
      textAlign = TextAlign.start,
      color = GSWColors.textSecondary,
      lineHeight = 16;

  final String prefix;
  final String termsLabel;
  final TextAlign textAlign;
  final Color color;
  final double lineHeight;

  @override
  State<LegalAgreementText> createState() => _LegalAgreementTextState();
}

class _LegalAgreementTextState extends State<LegalAgreementText> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();

    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        // Figma 12.5c: read the terms in a sheet over sign-up, never leaving it.
        showSignUpLegalSheet(
          context: context,
          title: 'Terms of Service',
          version: 'Version 1.3 · 14 October 2026',
          body: const TermsOfServiceScreen(embedded: true),
        );
      };

    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        showSignUpLegalSheet(
          context: context,
          title: 'Privacy Policy',
          version: 'Version 1.3 · 14 October 2026',
          body: const PrivacyPolicyScreen(embedded: true),
        );
      };
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = GSWTextStyles.labelSmall.copyWith(
      color: widget.color,
      height: widget.lineHeight / 12,
    );

    final link = base.copyWith(color: GSWColors.textAccent);

    return SizedBox(
      width: double.infinity,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: widget.prefix),
            TextSpan(text: widget.termsLabel, style: link, recognizer: _termsRecognizer),
            const TextSpan(text: ' and '),
            TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacyRecognizer),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: widget.textAlign,
      ),
    );
  }
}
