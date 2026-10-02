import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';

class LegalAgreementText extends StatefulWidget {
  const LegalAgreementText({super.key});

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
        context.push(GSWRoutes.termsOfService);
      };

    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        context.push(GSWRoutes.privacyPolicy);
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
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'By continuing you agree to our ',
            style: GSWTextStyles.labelSmall.copyWith(
              color: GSWColors.textTertiary,
            ),
          ),
          TextSpan(
            text: 'Terms of Service ',
            style: GSWTextStyles.labelSmall.copyWith(
              color: GSWColors.textAccent,
            ),
            recognizer: _termsRecognizer,
          ),
          TextSpan(
            text: 'and ',
            style: GSWTextStyles.labelSmall.copyWith(
              color: GSWColors.textTertiary,
            ),
          ),
          TextSpan(
            text: 'Privacy Policy',
            style: GSWTextStyles.labelSmall.copyWith(
              color: GSWColors.textAccent,
            ),
            recognizer: _privacyRecognizer,
          ),
          TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
