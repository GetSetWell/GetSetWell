import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/phone_auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,

    required this.phone,

    required this.verificationId,

    required this.onBack,

    required this.onChangeNumber,

    required this.onVerified,

    this.onNotOnWhatsApp,
  });

  final String phone;

  final String verificationId;

  final VoidCallback onBack;

  final VoidCallback onChangeNumber;

  /// Called after Supabase successfully verifies the OTP.

  final ValueChanged<bool> onVerified;

  /// We can wire SMS fallback here later.

  final VoidCallback? onNotOnWhatsApp;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;

  static const int _initialResendSeconds = 30;

  final TextEditingController _otpController = TextEditingController();

  final FocusNode _otpFocusNode = FocusNode();

  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  final ProfileRepository _profileRepository = ProfileRepository();

  late final TapGestureRecognizer _changeNumberRecognizer;

  Timer? _resendTimer;

  int _resendSeconds = _initialResendSeconds;

  bool _isVerifying = false;

  bool _isResending = false;
  bool _firebaseOtpVerified = false;

  String? _errorMessage;

  late String _activeVerificationId;

  @override
  void initState() {
    super.initState();

    _activeVerificationId = widget.verificationId;

    _changeNumberRecognizer = TapGestureRecognizer()..onTap = widget.onChangeNumber;

    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _otpFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();

    _otpController.dispose();

    _otpFocusNode.dispose();

    _changeNumberRecognizer.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------

  // PHONE DISPLAY

  // ---------------------------------------------------------------------------

  String get _formattedPhone {
    try {
      final phone = PhoneNumber.parse(widget.phone);

      final formattedNsn = phone.formatNsn(format: NsnFormat.international);

      return '+${phone.countryCode} $formattedNsn';
    } catch (_) {
      return widget.phone;
    }
  }

  // ---------------------------------------------------------------------------

  // OTP

  // ---------------------------------------------------------------------------

  String get _code => _otpController.text;

  void _handleOtpChanged(String value) {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    } else {
      setState(() {});
    }

    if (value.length == _otpLength) {
      _verifyCode();
    }
  }

  // Firebase Auth onCreate triggers run asynchronously. Refresh the ID token
  // until the backend has assigned the Supabase authenticated role.
  Future<void> _waitForSupabaseRole() async {
    for (var attempt = 0; attempt < 15; attempt++) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Your Firebase sign-in session is unavailable.');
      }

      final token = await user.getIdTokenResult(true);
      if (token.claims?['role'] == 'authenticated') {
        return;
      }

      if (attempt < 14) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw TimeoutException('Your account is taking longer to set up. Please try again.');
  }

  Future<void> _verifyCode() async {
    if (_isVerifying || _isResending) return;

    final code = _otpController.text;
    if (code.length != _otpLength) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // The existing phone service may reject a successful Firebase sign-in
      // while the asynchronously assigned custom role is still unavailable.
      if (!_firebaseOtpVerified) {
        try {
          await _phoneAuthService.verifyOtp(
            phone: widget.phone,
            otp: code,
            verificationId: _activeVerificationId,
          );
          _firebaseOtpVerified = true;
        } on StateError catch (error) {
          if (error.message != 'Firebase token is missing the authenticated role claim.' ||
              FirebaseAuth.instance.currentUser == null) {
            rethrow;
          }
          _firebaseOtpVerified = true;
        }
      }

      await _waitForSupabaseRole();
      await Supabase.instance.client.rpc('ensure_customer_identity');
    } catch (error) {
      debugPrint('OTP sign-in/setup failed: $error');
      if (!mounted) return;

      final String message;
      if (error is FirebaseAuthException &&
          (error.code == 'invalid-verification-code' ||
              error.code == 'invalid-verification-id' ||
              error.code == 'session-expired')) {
        message = 'That code is not right or has expired. Try again.';
      } else if (error is TimeoutException) {
        message = 'Account setup is taking longer than expected. Please try again.';
      } else {
        message = 'We could not finish signing you in. Please try again.';
      }

      setState(() {
        _errorMessage = message;
        _isVerifying = false;
      });
      _otpFocusNode.requestFocus();
      return;
    }

    // Push permission or FCM availability must not block a successful login.
    try {
      await PushNotificationService().registerCurrentDevice();
    } catch (error) {
      debugPrint('Push device registration failed after login: $error');
    }

    if (!mounted) return;

    try {
      final hasCompletedProfile = await _profileRepository.hasCompletedProfile();
      if (!mounted) return;
      widget.onVerified(hasCompletedProfile);
    } catch (error) {
      debugPrint('PROFILE CHECK ERROR: $error');
      if (!mounted) return;
      widget.onVerified(false);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  // RESEND

  // ---------------------------------------------------------------------------

  void _startResendTimer() {
    _resendTimer?.cancel();

    setState(() {
      _resendSeconds = _initialResendSeconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();

        return;
      }

      if (_resendSeconds <= 1) {
        timer.cancel();

        setState(() {
          _resendSeconds = 0;
        });

        return;
      }

      setState(() {
        _resendSeconds--;
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0 || _isResending) {
      return;
    }

    setState(() {
      _isResending = true;

      _errorMessage = null;
    });

    try {
      await _phoneAuthService.sendOtp(phone: widget.phone);

      final newVerificationId = _phoneAuthService.verificationId;

      if (newVerificationId == null || newVerificationId.isEmpty) {
        throw StateError('Firebase resend verification ID is missing.');
      }

      _activeVerificationId = newVerificationId;
      _firebaseOtpVerified = false;

      if (!mounted) return;

      _otpController.clear();

      _startResendTimer();

      _otpFocusNode.requestFocus();
    } catch (error) {
      debugPrint('Failed to resend OTP: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not resend the code. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------

  // BUILD

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      resizeToAvoidBottomInset: false,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildBackButton(),

                    const SizedBox(height: 32),

                    _buildHeader(),

                    const SizedBox(height: 32),

                    _buildCodeBoxes(),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,

                        child: Text(
                          _errorMessage!,

                          textAlign: TextAlign.center,

                          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.error),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    _buildResend(),
                  ],
                ),
              ),
            ),

            _buildBottomHelper(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  // BACK

  // ---------------------------------------------------------------------------

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,

      shape: CircleBorder(side: BorderSide(color: GSWColors.borderSecondary)),

      child: InkWell(
        onTap: widget.onBack,

        customBorder: const CircleBorder(),

        child: const SizedBox(
          width: 46,

          height: 46,

          child: Center(
            child: Icon(Icons.chevron_left_rounded, size: 30, color: GSWColors.primary),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  // HEADER

  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'CHECK YOUR WHATSAPP',

          style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
        ),

        const SizedBox(height: 12),

        Text.rich(
          TextSpan(
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),

            children: [
              const TextSpan(text: 'We sent a 6 digit code to '),

              TextSpan(text: _formattedPhone),

              const TextSpan(text: '. '),

              TextSpan(
                text: 'Change number',

                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textAccent),

                recognizer: _changeNumberRecognizer,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------

  // CODE BOXES

  // ---------------------------------------------------------------------------

  Widget _buildCodeBoxes() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () {
        _otpFocusNode.requestFocus();
      },

      child: Stack(
        children: [
          Row(
            children: [
              for (var index = 0; index < _otpLength; index++) ...[
                Expanded(child: _buildCodeBox(index)),

                if (index < _otpLength - 1) const SizedBox(width: 8),
              ],
            ],
          ),

          // Single input powers all six boxes.
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,

              child: TextField(
                controller: _otpController,

                focusNode: _otpFocusNode,

                autofocus: true,

                keyboardType: TextInputType.number,

                textInputAction: TextInputAction.done,

                autofillHints: const [AutofillHints.oneTimeCode],

                autocorrect: false,

                enableSuggestions: false,

                showCursor: false,

                maxLength: _otpLength,

                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,

                  LengthLimitingTextInputFormatter(_otpLength),
                ],

                style: const TextStyle(color: Colors.transparent),

                cursorColor: Colors.transparent,

                decoration: const InputDecoration(
                  border: InputBorder.none,

                  counterText: '',

                  contentPadding: EdgeInsets.zero,
                ),

                onChanged: _handleOtpChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    final hasDigit = index < _code.length;

    final digit = hasDigit ? _code[index] : '';

    final activeIndex = _code.length >= _otpLength ? _otpLength - 1 : _code.length;

    final isActive = _otpFocusNode.hasFocus && index == activeIndex && !_isVerifying;

    final hasValue = index < _code.length;

    final hasError = _errorMessage != null;

    final borderColor = hasError
        ? GSWColors.error
        : hasValue
        ? GSWColors.primary
        : GSWColors.surfaceInteractive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 10),

      height: 64,

      alignment: Alignment.center,

      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(width: isActive ? 1.5 : 1.5, color: borderColor),
      ),

      child: Text(
        digit,

        style: GSWTextStyles.titleMedium.copyWith(
          color: hasError ? GSWColors.error : GSWColors.textPrimary,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  // RESEND

  // ---------------------------------------------------------------------------

  Widget _buildResend() {
    final canResend = _resendSeconds == 0 && !_isResending;

    final label = _isResending
        ? 'Sending...'
        : canResend
        ? 'Resend code'
        : 'Resend code in 0:${_resendSeconds.toString().padLeft(2, '0')}';

    return SizedBox(
      width: double.infinity,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: canResend ? _resendCode : null,

        child: Text(
          label,

          textAlign: TextAlign.center,

          style: GSWTextStyles.bodySmall.copyWith(
            fontSize: 12,

            height: 16 / 12,

            color: canResend ? GSWColors.primary : GSWColors.textTertiary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  // BOTTOM

  // ---------------------------------------------------------------------------

  Widget _buildBottomHelper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),

      child: SizedBox(
        width: double.infinity,

        child: Text(
          'The code fills in on its own once it arrives.',

          textAlign: TextAlign.center,

          style: GSWTextStyles.bodySmall.copyWith(
            fontSize: 12,

            height: 16 / 12,

            color: GSWColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
