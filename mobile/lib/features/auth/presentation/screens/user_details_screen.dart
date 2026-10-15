import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_checkbox.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/legal/presentation/widgets/legal_agreement_text.dart';

import '../../data/repositories/profile_repository.dart';

/// 3.5 Your details. Name only: Dubai is the only live city, so it is saved
/// without asking (Figma note 816:2620). The checkbox records that the
/// person is 18 or over and agrees to the Terms and Privacy Policy.
class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key, required this.intent, required this.onCompleted});

  final AuthFlowIntent intent;
  final Future<void> Function() onCompleted;

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();

  final ProfileRepository _profileRepository = ProfileRepository();

  /// The only live city (v1.2 policy).
  static const String _city = 'Dubai';

  bool _agreed = false;

  bool _isSaving = false;

  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  bool get _canContinue => _nameController.text.trim().isNotEmpty && _agreed && !_isSaving;

  String get _buttonLabel {
    if (widget.intent.type == AuthFlowType.returnToCaller) {
      return 'Continue booking';
    }

    switch (widget.intent.entryPoint) {
      case AuthEntryPoint.helpMeChoose:
        return 'Send my request';

      case AuthEntryPoint.getStarted:
        return 'Create my account';

      // Reached from 3.9 "Create my account": the button reads Continue
      // (Figma note 1006:3364).
      case AuthEntryPoint.existingAccount:
        return 'Continue';
    }
  }

  Future<void> _continue() async {
    if (!_canContinue) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _profileRepository.saveBasicProfile(fullName: _nameController.text.trim(), city: _city);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to save profile: $error');
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = 'We could not save your name. Please try again.';
      });

      return;
    }

    if (!mounted) return;

    try {
      // Stays busy until the next screen is open, so a second tap cannot
      // send the request twice.
      await widget.onCompleted();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usually reached with go(), which leaves nothing to pop: Android back then
    // opens Home instead of closing the app.
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(GSWRoutes.home);
      },
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Almost there',
                          style: GSWTextStyles.titleLarge.copyWith(
                            color: GSWColors.textPrimary,
                            height: 30 / 24,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          "Just your name, so your trainer knows who they're meeting.",
                          style: GSWTextStyles.bodyMedium.copyWith(
                            color: GSWColors.textSecondary,
                            height: 20 / 14,
                          ),
                        ),

                        const SizedBox(height: 32),

                        GSWTextField(
                          size: GSWTextFieldSize.large,
                          controller: _nameController,
                          label: 'Full name',
                          hintText: 'Your full name',
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.name,
                          errorText: _errorMessage,
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                          // Keyboard Done submits when everything is filled in.
                          onComplete: (_) {
                            if (_canContinue) {
                              _continue();
                            }
                          },
                        ),

                        const SizedBox(height: 32),

                        _buildConsent(),
                      ],
                    ),
                  ),
                ),
              ),

              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GSWCheckbox(
          value: _agreed,
          onChanged: _isSaving
              ? null
              : (value) {
                  setState(() {
                    _agreed = value;
                  });
                },
        ),

        const SizedBox(width: 8),

        const Expanded(child: LegalAgreementText.signUpConsent()),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: GSWButton(
        size: GSWButtonSize.large,
        variant: _canContinue || _isSaving ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
        label: _buttonLabel,
        isLoading: _isSaving,
        onPressed: _canContinue ? _continue : null,
      ),
    );
  }
}
