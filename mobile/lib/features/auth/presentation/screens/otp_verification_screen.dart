import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/gsw_icons.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/firebase_phone_verification_service.dart';
import '../../data/services/phone_auth_service.dart';
import '../../domain/phone_display.dart';

/// 3.2 Enter the code, 3.3 Wrong code, 3.4 Didn't get the code (SMS),
/// and the "Code verified" state that sits behind the 3.8 / 3.9 sheets.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    required this.onBack,
    required this.onChangeNumber,
    required this.onVerified,
    this.resendToken,
    this.autoVerified = false,
  });

  final String phone;

  final String verificationId;

  /// Firebase resend token from the first send, passed back on resend.
  final int? resendToken;

  /// Android verified the number instantly; skip straight to sign-in setup.
  final bool autoVerified;

  final VoidCallback onBack;

  final VoidCallback onChangeNumber;

  /// Called once the number is verified and the profile check succeeded.
  /// The screen stays busy until the returned future completes, so the
  /// router can show sheets or submit requests without a second tap.
  final Future<void> Function(bool hasCompletedProfile) onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

enum _OtpStage {
  /// Typing the code.
  entry,

  /// Firebase sign-in and Supabase setup in progress.
  verifying,

  /// Signed in, the router is deciding where to go (sheets may be open).
  verified,

  /// Signed in, but the account check or the next step failed. Retryable.
  setupFailed,
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;

  static const int _initialResendSeconds = 30;

  static const int _maxAttempts = 3;

  final TextEditingController _otpController = TextEditingController();

  final FocusNode _otpFocusNode = FocusNode();

  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  final ProfileRepository _profileRepository = ProfileRepository();

  late final TapGestureRecognizer _changeNumberRecognizer;

  StreamSubscription<PhoneAutoVerification>? _autoVerificationSubscription;

  Timer? _resendTimer;

  int _resendSeconds = _initialResendSeconds;

  _OtpStage _stage = _OtpStage.entry;

  bool _isResending = false;

  /// Firebase has accepted the code (or auto-verified). Retrying after this
  /// point never asks for the code again.
  bool _signedIn = false;

  bool _showHelp = false;

  int _attemptsLeft = _maxAttempts;

  String? _errorMessage;

  late String _activeVerificationId;

  int? _resendToken;

  bool get _isBusy => _stage == _OtpStage.verifying || _stage == _OtpStage.verified;

  bool get _codeLocked => _attemptsLeft <= 0;

  @override
  void initState() {
    super.initState();

    _activeVerificationId = widget.verificationId;

    _resendToken = widget.resendToken;

    _changeNumberRecognizer = TapGestureRecognizer()..onTap = widget.onChangeNumber;

    _autoVerificationSubscription = FirebasePhoneVerificationService.autoVerifications.listen(
      _handleAutoVerification,
    );

    _startResendTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.autoVerified && FirebaseAuth.instance.currentUser != null) {
        _signedIn = true;
        _completeSignIn();
        return;
      }

      _otpFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();

    _autoVerificationSubscription?.cancel();

    _otpController.dispose();

    _otpFocusNode.dispose();

    _changeNumberRecognizer.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // OTP
  // ---------------------------------------------------------------------------

  String get _code => _otpController.text;

  void _handleOtpChanged(String value) {
    setState(() {
      if (_stage == _OtpStage.entry) {
        _errorMessage = null;
      }
    });

    if (value.length == _otpLength) {
      _verifyCode();
    }
  }

  /// Android read the SMS on its own after the code screen opened and Firebase
  /// already signed the user in.
  void _handleAutoVerification(PhoneAutoVerification event) {
    if (!mounted || event.phone != widget.phone || _isBusy || _signedIn) return;

    final smsCode = event.smsCode;

    if (smsCode != null && smsCode.length == _otpLength) {
      _otpController.value = TextEditingValue(
        text: smsCode,
        selection: TextSelection.collapsed(offset: smsCode.length),
      );
    }

    _signedIn = true;

    _completeSignIn();
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
    if (_isBusy || _isResending || _codeLocked) return;

    final code = _otpController.text;

    if (code.length != _otpLength) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _stage = _OtpStage.verifying;
      _errorMessage = null;
    });

    try {
      await _phoneAuthService.verifyOtp(otp: code, verificationId: _activeVerificationId);

      _signedIn = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('OTP sign-in failed: $error');
      }

      if (!mounted) return;

      _handleCodeError(error);

      return;
    }

    await _completeSignIn();
  }

  void _handleCodeError(Object error) {
    String message;

    if (error is FirebaseAuthException && error.code == 'invalid-verification-code') {
      _attemptsLeft = _attemptsLeft - 1;

      if (_attemptsLeft <= 0) {
        message = 'That code is not right. Ask for a new code to try again.';
      } else if (_attemptsLeft == 1) {
        message = 'That code is not right. 1 try left.';
      } else {
        message = 'That code is not right. $_attemptsLeft tries left.';
      }
    } else if (error is FirebaseAuthException &&
        (error.code == 'session-expired' || error.code == 'invalid-verification-id')) {
      _attemptsLeft = 0;
      message = 'This code has expired. Ask for a new one.';
    } else if (error is FirebaseAuthException && error.code == 'network-request-failed') {
      message = 'No connection. Check your internet and try again.';
    } else if (error is FirebaseAuthException && error.code == 'too-many-requests') {
      _attemptsLeft = 0;
      message = 'Too many tries. Wait a few minutes, then ask for a new code.';
    } else {
      message = 'We could not check that code. Please try again.';
    }

    setState(() {
      _stage = _OtpStage.entry;
      _errorMessage = message;
    });

    if (!_codeLocked) {
      _otpFocusNode.requestFocus();
    }
  }

  /// Runs after Firebase sign-in: Supabase role, customer identity, push
  /// registration, profile check, then hands over to the router.
  Future<void> _completeSignIn() async {
    if (!mounted) return;

    setState(() {
      _stage = _OtpStage.verifying;
      _errorMessage = null;
    });

    final bool hasCompletedProfile;

    try {
      await _waitForSupabaseRole();

      await Supabase.instance.client.rpc('ensure_customer_identity');

      hasCompletedProfile = await _profileRepository.hasCompletedProfile();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Sign-in setup or profile check failed: $error');
      }

      if (!mounted) return;

      setState(() {
        _stage = _OtpStage.setupFailed;
        _errorMessage = error is TimeoutException
            ? 'Your account is taking longer than usual to set up.'
            : 'We could not check your account.';
      });

      return;
    }

    // Push permission or FCM availability must not block a successful login.
    try {
      final push = PushNotificationService();
      await push.requestPermissionIfNeeded();
      await push.registerCurrentDevice();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Push device registration failed after login: $error');
      }
    }

    if (!mounted) return;

    setState(() {
      _stage = _OtpStage.verified;
    });

    try {
      await widget.onVerified(hasCompletedProfile);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Post-verification routing failed: $error');
      }

      if (mounted) {
        setState(() {
          _stage = _OtpStage.setupFailed;
          _errorMessage = 'Something went wrong after signing you in.';
        });
      }

      return;
    }

    // Still here means the router did not navigate away (for example a
    // request could not be sent). Offer a retry instead of a dead screen.
    if (!mounted) return;

    if (_stage == _OtpStage.verified && (ModalRoute.of(context)?.isCurrent ?? true)) {
      setState(() {
        _stage = _OtpStage.setupFailed;
        _errorMessage = null;
      });
    }
  }

  void _retrySetup() {
    if (_isBusy) return;

    if (_signedIn && FirebaseAuth.instance.currentUser != null) {
      _completeSignIn();
      return;
    }

    setState(() {
      _stage = _OtpStage.entry;
      _errorMessage = null;
      _otpController.clear();
    });

    _otpFocusNode.requestFocus();
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
    if (_resendSeconds > 0 || _isResending || _isBusy) {
      return;
    }

    setState(() {
      _isResending = true;

      _errorMessage = null;
    });

    try {
      final request = await _phoneAuthService.sendOtp(
        phone: widget.phone,
        forceResendingToken: _resendToken,
      );

      if (!mounted) return;

      _resendToken = request.resendToken ?? _resendToken;

      if (request.autoVerified) {
        _signedIn = true;

        setState(() {
          _showHelp = false;
        });

        await _completeSignIn();

        return;
      }

      if (request.verificationId.isEmpty) {
        throw StateError('Firebase resend verification ID is missing.');
      }

      _activeVerificationId = request.verificationId;

      _otpController.clear();

      setState(() {
        _attemptsLeft = _maxAttempts;
        _showHelp = false;
        _stage = _OtpStage.entry;
      });

      _startResendTimer();

      _otpFocusNode.requestFocus();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to resend OTP: $error');
      }

      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not send a new code. Try again in a moment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  String get _countdownLabel => '0:${_resendSeconds.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Once signed in, back goes through onBack so it also signs out.
      canPop: !_isBusy && !_showHelp && !_signedIn,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isBusy) return;

        if (_showHelp) {
          setState(() {
            _showHelp = false;
          });
          return;
        }

        widget.onBack();
      },
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,

        resizeToAvoidBottomInset: false,

        body: SafeArea(child: _showHelp ? _buildHelpView() : _buildCodeView()),
      ),
    );
  }

  Widget _buildCodeView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                _buildBackButton(onTap: _isBusy ? null : widget.onBack),

                const SizedBox(height: 32),

                _buildHeader(),

                const SizedBox(height: 32),

                _buildCodeBoxes(),

                // 32px in Figma; every status line carries 4px of padding
                // above and below (its tap area), so 28 + 4.
                const SizedBox(height: 28),

                ..._buildStatusLines(),
              ],
            ),
          ),
        ),

        _buildBottomHelper(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BACK
  // ---------------------------------------------------------------------------

  Widget _buildBackButton({required VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,

      shape: const CircleBorder(side: BorderSide(color: GSWColors.borderSecondary)),

      child: InkWell(
        onTap: onTap,

        customBorder: const CircleBorder(),

        child: SizedBox(
          width: 46,

          height: 46,

          child: Center(
            child: SvgPicture.asset(
              GSWIcons.arrowheadLeft,
              width: 30,
              height: 30,
              colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
    );
  }

  TextStyle get _introStyle =>
      GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14);

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildTitle('Check your messages'),

        const SizedBox(height: 12),

        Text.rich(
          TextSpan(
            style: _introStyle,

            children: [
              const TextSpan(text: 'We sent a 6 digit code by SMS to '),

              TextSpan(text: formatPhoneForDisplay(widget.phone)),

              const TextSpan(text: '. '),

              TextSpan(
                text: 'Change number',

                style: _introStyle.copyWith(color: GSWColors.textAccent),

                recognizer: _isBusy ? null : _changeNumberRecognizer,
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
    final inputEnabled = !_isBusy && !_codeLocked && _stage != _OtpStage.setupFailed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: inputEnabled ? _otpFocusNode.requestFocus : null,

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

                enabled: inputEnabled,

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

                onSubmitted: (_) => _verifyCode(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    final digit = index < _code.length ? _code[index] : '';

    final activeIndex = _code.length >= _otpLength ? _otpLength - 1 : _code.length;

    final isActive =
        _otpFocusNode.hasFocus &&
        index == activeIndex &&
        _code.length < _otpLength &&
        _stage == _OtpStage.entry;

    final hasError =
        _stage == _OtpStage.entry && _errorMessage != null && _code.length == _otpLength;

    final Color? borderColor = hasError
        ? GSWColors.borderError
        : isActive
        ? GSWColors.borderFocused
        : null;

    return Container(
      height: 64,

      alignment: Alignment.center,

      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,

        borderRadius: BorderRadius.circular(GSWRadius.control),

        border: borderColor == null ? null : Border.all(width: 1.5, color: borderColor),
      ),

      child: Text(
        digit,

        style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS LINES (resend, errors, "Didn't get the code?")
  // ---------------------------------------------------------------------------

  TextStyle get _smallStyle =>
      GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary);

  /// Gap between status lines. Figma uses 32; each line adds 4px padding
  /// above and below, tappable or not, so the rhythm never shifts.
  static const double _statusGap = 24;

  Widget _centredLine(String text, {Color? color, VoidCallback? onTap}) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),

      child: SizedBox(
        width: double.infinity,

        child: Text(
          text,

          textAlign: TextAlign.center,

          style: _smallStyle.copyWith(color: color),
        ),
      ),
    );

    if (onTap == null) return line;

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: line);
  }

  /// "Didn't get the code?" link. Inert while signing in, as it sits behind
  /// the 3.8 / 3.9 sheets in Figma.
  Widget _helpLine({required bool enabled}) {
    return _centredLine(
      "Didn't get the code?",
      color: GSWColors.textAccent,
      onTap: enabled
          ? () {
              FocusScope.of(context).unfocus();

              setState(() {
                _showHelp = true;
              });
            }
          : null,
    );
  }

  List<Widget> _buildStatusLines() {
    switch (_stage) {
      case _OtpStage.verifying:
        return [_centredLine('Checking your code...')];

      case _OtpStage.verified:
        // Figma 3.8 / 3.9 background: "Code verified", then the help link.
        return [
          _centredLine('Code verified'),

          const SizedBox(height: _statusGap),

          _helpLine(enabled: false),
        ];

      case _OtpStage.setupFailed:
        return [
          _centredLine(
            _errorMessage == null ? 'Code verified' : '${_errorMessage!} Your code was accepted.',
            color: _errorMessage == null ? null : GSWColors.error,
          ),

          const SizedBox(height: _statusGap),

          _centredLine('Try again', color: GSWColors.textAccent, onTap: _retrySetup),
        ];

      case _OtpStage.entry:
        final canResend = _resendSeconds == 0 && !_isResending;

        return [
          if (_errorMessage != null) ...[
            _centredLine(_errorMessage!, color: GSWColors.error),

            const SizedBox(height: _statusGap),
          ],

          if (_isResending)
            _centredLine('Sending a new code...')
          else if (canResend)
            _centredLine('Resend code', color: GSWColors.textAccent, onTap: _resendCode)
          else
            _centredLine('Resend code in $_countdownLabel'),

          const SizedBox(height: _statusGap),

          _helpLine(enabled: true),
        ];
    }
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

          style: _smallStyle,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3.4 DIDN'T GET THE CODE (SMS version of "Not on WhatsApp")
  // ---------------------------------------------------------------------------

  Widget _buildHelpView() {
    final canResend = _resendSeconds == 0 && !_isResending && !_isBusy;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(
                  onTap: _isBusy
                      ? null
                      : () {
                          setState(() {
                            _showHelp = false;
                          });
                        },
                ),

                const SizedBox(height: 32),

                _buildTitle("Didn't get the code?"),

                const SizedBox(height: 12),

                Text(
                  'Codes come by SMS and usually arrive within a minute. '
                  'Signal and some message filters can slow them down.',
                  style: _introStyle,
                ),

                const SizedBox(height: 32),

                _buildHelpSteps(),

                if (_errorMessage != null) ...[
                  // 16px to the text; the line carries 4px of padding.
                  const SizedBox(height: 12),

                  _centredLine(_errorMessage!, color: GSWColors.error),
                ],
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GSWButton(
                size: GSWButtonSize.large,
                variant: canResend ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
                label: canResend || _isResending
                    ? 'Send a new code'
                    : 'Send a new code in $_countdownLabel',
                isLoading: _isResending,
                onPressed: canResend ? _resendCode : null,
              ),

              const SizedBox(height: 8),

              GSWButton(
                size: GSWButtonSize.large,
                variant: GSWButtonVariant.tertiary,
                label: 'Use a different number',
                onPressed: _isBusy ? null : widget.onChangeNumber,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSteps() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpStep(
            number: '1',
            title: 'Check the number',
            body: 'We sent it to ${formatPhoneForDisplay(widget.phone)}.',
          ),

          const SizedBox(height: 14),

          _buildHelpStep(
            number: '2',
            title: 'Ask for a new code',
            body: 'Only the newest code works, and your answers so far are kept.',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep({required String number, required String title, required String body}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: GSWColors.surfaceInteractive,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GSWTextStyles.labelMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 18 / 13,
              color: GSWColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GSWTextStyles.labelLarge.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 21 / 15,
                  color: GSWColors.textPrimary,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                body,
                style: GSWTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  height: 18 / 13,
                  color: GSWColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
