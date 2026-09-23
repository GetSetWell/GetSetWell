import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';

import '../../data/repositories/profile_repository.dart';

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

  static const String _selectedCity = 'Dubai';

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);

    _nameController.dispose();

    super.dispose();
  }

  void _handleNameChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });

      return;
    }

    setState(() {});
  }

  bool get _canContinue {
    return _nameController.text.trim().isNotEmpty && !_isSaving;
  }

  String get _buttonLabel {
    if (_isSaving) {
      switch (widget.intent.entryPoint) {
        case AuthEntryPoint.getStarted:
          return 'Creating account...';

        case AuthEntryPoint.helpMeChoose:
          return 'Saving...';

        case AuthEntryPoint.existingAccount:
          return 'Saving...';
      }
    }

    switch (widget.intent.entryPoint) {
      case AuthEntryPoint.getStarted:
        return 'Create account';

      case AuthEntryPoint.helpMeChoose:
        return 'Send request';

      case AuthEntryPoint.existingAccount:
        return 'Continue to trainers';
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
      await _profileRepository.saveBasicProfile(
        fullName: _nameController.text.trim(),
        city: _selectedCity,
      );

      if (!mounted) return;

      await widget.onCompleted();
    } catch (error) {
      debugPrint('Failed to save profile: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not save your details. Please try again.';
      });
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
    return Scaffold(
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
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALMOST THERE',
                        style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Your name and city, so your trainer knows who they are meeting.',
                        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                      ),

                      const SizedBox(height: 32),

                      GSWTextField(
                        size: GSWTextFieldSize.large,
                        controller: _nameController,
                        label: 'Full name',
                        hintText: 'Nada Khoury',
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.name,
                        errorText: _errorMessage,
                        onChanged: (_) {
                          setState(() {});
                        },
                        onComplete: (_) {
                          if (_canContinue) {
                            _continue();
                          }
                        },
                      ),

                      const SizedBox(height: 32),

                      Text(
                        'City',
                        style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
                      ),

                      const SizedBox(height: 8),

                      _buildCities(),
                    ],
                  ),
                ),
              ),
            ),

            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCities() {
    return Row(
      children: [
        _buildCityOption(city: 'Dubai', selected: true),

        const SizedBox(width: 8),

        _buildCityOption(city: 'Abu Dhabi', soon: true),

        const SizedBox(width: 8),

        _buildCityOption(city: 'Sharjah', soon: true),
      ],
    );
  }

  Widget _buildCityOption({required String city, bool selected = false, bool soon = false}) {
    return Expanded(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? GSWColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            width: 1,
            color: selected ? GSWColors.primary : GSWColors.borderSecondary,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                city,
                style: GSWTextStyles.labelLarge.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textTertiary,
                ),
              ),

              if (soon) ...[
                const SizedBox(width: 6),

                Text(
                  'Soon',
                  style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: GSWButton(
        size: GSWButtonSize.large,
        variant: _canContinue ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
        label: _buttonLabel,
        onPressed: _canContinue ? _continue : null,
      ),
    );
  }
}
