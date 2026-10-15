import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 12.2d Change number, new number (Figma 1263:4223) and
/// 12.2e Change number, enter the code (Figma 1263:4318).
/// Codes go by SMS (Firebase Phone Auth), never WhatsApp.
class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key, required this.currentPhone});

  final String currentPhone;

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _countryController = TextEditingController();

  final TextEditingController _otpController = TextEditingController();

  final FocusNode _otpFocusNode = FocusNode();

  Timer? _resendTimer;

  int _resendSeconds = 30;

  /// Mirrors [_resendSeconds] so the "Didn't get the code?" sheet can count down.
  final ValueNotifier<int> _resendNotifier = ValueNotifier<int>(30);

  late final TapGestureRecognizer _changeNumberRecognizer;

  bool _isResending = false;

  late final CountryService _countryService;

  late final List<Country> _countries;

  late Country _selectedCountry;

  final LayerLink _countryLayerLink = LayerLink();

  OverlayEntry? _countryOverlayEntry;

  bool _otpSent = false;

  bool _isSubmitting = false;

  String? _error;

  String? _pendingPhone;

  String? _verificationId;

  int? _resendToken;

  int _phoneChangeGeneration = 0;

  bool _isCompletingPhoneChange = false;

  bool _phoneChangeCompleted = false;

  @override
  void initState() {
    super.initState();

    _countryService = CountryService();

    _countries = _countryService.getAll()..sort((a, b) => a.name.compareTo(b.name));

    _selectedCountry = _countryService.findByCode('AE')!;

    _syncCountryField();

    _phoneController.addListener(_handlePhoneChanged);

    _otpFocusNode.addListener(_handleOtpFocusChanged);

    _changeNumberRecognizer = TapGestureRecognizer()
      ..onTap = () {
        if (!_isSubmitting) _changeNumberAgain();
      };
  }

  void _handleOtpFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideCountryPicker();

    _phoneController.removeListener(_handlePhoneChanged);

    _phoneController.dispose();

    _countryController.dispose();

    _otpController.dispose();

    _otpFocusNode.removeListener(_handleOtpFocusChanged);

    _otpFocusNode.dispose();

    _changeNumberRecognizer.dispose();

    _resendNotifier.dispose();

    _resendTimer?.cancel();

    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSubmitting || _isCompletingPhoneChange || _phoneChangeCompleted) return;

    final newPhone = _fullPhoneNumber;
    if (newPhone == null) {
      setState(() => _error = 'Enter a valid mobile number.');
      return;
    }

    if (newPhone == _normalizePhone(widget.currentPhone)) {
      setState(() => _error = 'Enter a different mobile number.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    _pendingPhone = newPhone;
    _verificationId = null;
    _resendToken = null;
    _phoneChangeGeneration++;

    await _requestPhoneVerification(newPhone, _phoneChangeGeneration);
  }

  Future<void> _requestPhoneVerification(String phone, int generation, {int? resendToken}) async {
    bool isCurrentRequest() =>
        mounted && generation == _phoneChangeGeneration && !_phoneChangeCompleted;

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Your session has expired. Please sign in again.',
        );
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: resendToken,
        verificationCompleted: (credential) {
          if (!isCurrentRequest()) return;
          _handleVerifiedCredential(credential, phone, generation);
        },
        verificationFailed: (error) {
          if (!isCurrentRequest() || _isCompletingPhoneChange) return;
          debugPrint('Phone change verification failed: ${error.code} ${error.message}');
          setState(() {
            _isSubmitting = false;
            _isResending = false;
            _error = _firebaseAuthMessage(error);
          });
        },
        codeSent: (verificationId, token) {
          if (!isCurrentRequest() || _isCompletingPhoneChange) return;
          _otpController.clear();
          setState(() {
            _pendingPhone = phone;
            _verificationId = verificationId;
            _resendToken = token;
            _otpSent = true;
            _isSubmitting = false;
            _isResending = false;
            _resendSeconds = 30;
            _error = null;
          });
          _resendNotifier.value = 30;
          _startResendTimer();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isCurrentRequest()) _otpFocusNode.requestFocus();
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (isCurrentRequest()) _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!isCurrentRequest()) return;
      debugPrint('Phone change request failed: ${error.code} ${error.message}');
      setState(() {
        _isSubmitting = false;
        _isResending = false;
        _error = _firebaseAuthMessage(error);
      });
    } catch (error) {
      if (!isCurrentRequest()) return;
      debugPrint('Phone change request failed: $error');
      setState(() {
        _isSubmitting = false;
        _isResending = false;
        _error = 'We could not send the verification code. Please try again.';
      });
    }
  }

  Future<void> _completePhoneChange(PhoneAuthCredential credential, String phone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Your session has expired. Please sign in again.',
      );
    }

    // Resolve the legacy customer UUID before changing the Firebase identity.
    final customerId = await CustomerIdentityService(client: _supabase).getCustomerId();

    // Never sign in with this credential: it belongs to the new phone number.
    await user.updatePhoneNumber(credential);
    await user.getIdToken(true);

    await _supabase
        .from('customer_profiles')
        .update({'phone': phone, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', customerId);
  }

  Future<void> _handleVerifiedCredential(
    PhoneAuthCredential credential,
    String phone,
    int generation,
  ) async {
    if (!mounted ||
        generation != _phoneChangeGeneration ||
        _isCompletingPhoneChange ||
        _phoneChangeCompleted) {
      return;
    }

    _isCompletingPhoneChange = true;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _completePhoneChange(credential, phone);
      _phoneChangeCompleted = true;
      _resendTimer?.cancel();
      if (!mounted) return;
      context.pop(true);
    } on FirebaseAuthException catch (error) {
      debugPrint('Phone change verification failed: ${error.code} ${error.message}');
      if (!mounted) return;
      setState(() => _error = _firebaseAuthMessage(error));
    } on PostgrestException catch (error) {
      debugPrint('Phone profile sync failed: ${error.code} ${error.message}');
      if (!mounted) return;
      setState(() {
        _error =
            'Your number was updated, but we could not update your profile. Please contact support.';
      });
    } catch (error) {
      debugPrint('Phone change verification failed: $error');
      if (!mounted) return;
      setState(() => _error = 'We could not verify the code. Please try again.');
    } finally {
      _isCompletingPhoneChange = false;
      if (mounted && !_phoneChangeCompleted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_isSubmitting || _isCompletingPhoneChange || _phoneChangeCompleted) return;

    final phone = _pendingPhone;
    final verificationId = _verificationId;
    if (phone == null || phone.isEmpty || verificationId == null) {
      setState(() => _error = 'Request a new verification code first.');
      return;
    }

    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    FocusScope.of(context).unfocus();
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);
    await _handleVerifiedCredential(credential, phone, _phoneChangeGeneration);
  }

  void _changeNumberAgain() {
    if (_isCompletingPhoneChange || _phoneChangeCompleted) return;
    _phoneChangeGeneration++; // Ignore late callbacks from the previous number.
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _otpController.clear();
      _pendingPhone = null;
      _verificationId = null;
      _resendToken = null;
      _error = null;
      _resendSeconds = 30;
      _isResending = false;
      _isSubmitting = false;
    });
    _resendNotifier.value = 30;
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        _resendNotifier.value = 0;
        return;
      }
      setState(() => _resendSeconds--);
      _resendNotifier.value = _resendSeconds;
    });
  }

  Future<void> _resendCode() async {
    final phone = _pendingPhone;
    if (phone == null ||
        phone.isEmpty ||
        _resendSeconds > 0 ||
        _isResending ||
        _isSubmitting ||
        _isCompletingPhoneChange ||
        _phoneChangeCompleted) {
      return;
    }

    setState(() {
      _isResending = true;
      _error = null;
    });

    _phoneChangeGeneration++;
    await _requestPhoneVerification(phone, _phoneChangeGeneration, resendToken: _resendToken);
  }

  void _handleOtpChanged(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 6) {
      digits = digits.substring(0, 6);
    }

    if (_otpController.text != digits) {
      _otpController.value = TextEditingValue(
        text: digits,

        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    if (_error != null) {
      setState(() {
        _error = null;
      });
    } else {
      setState(() {});
    }

    if (digits.length == 6 && !_isSubmitting) {
      _verifyCode();
    }
  }

  Widget _buildOtpEntry() {
    final code = _otpController.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () {
        _otpFocusNode.requestFocus();
      },

      child: Stack(
        children: [
          Row(
            children: [
              for (var index = 0; index < 6; index++) ...[
                Expanded(
                  child: _buildOtpCodeBox(index: index, code: code),
                ),

                if (index < 5) const SizedBox(width: 8),
              ],
            ],
          ),

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

                maxLength: 6,

                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,

                  LengthLimitingTextInputFormatter(6),
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

  Widget _buildOtpCodeBox({required int index, required String code}) {
    final hasDigit = index < code.length;

    final digit = hasDigit ? code[index] : '';

    final hasError = _error != null && code.length == 6;

    final activeIndex = code.length >= 6 ? 5 : code.length;

    final isActive = _otpFocusNode.hasFocus && index == activeIndex && code.length < 6;

    // Filled and empty boxes have no border; only the active box (focused)
    // or a wrong full code (error) shows one (Figma 1263:4342).
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

        style: GSWTextStyles.titleLarge.copyWith(height: 1, color: GSWColors.textPrimary),
      ),
    );
  }

  TextStyle get _smallStyle =>
      GSWTextStyles.bodySmall.copyWith(height: 16 / 12, color: GSWColors.textTertiary);

  Widget _centredLine(String text, {Color? color, VoidCallback? onTap}) {
    final line = SizedBox(
      width: double.infinity,

      child: Text(text, textAlign: TextAlign.center, style: _smallStyle.copyWith(color: color)),
    );

    if (onTap == null) return line;

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: line);
  }

  Widget _buildResend() {
    final canResend = _resendSeconds == 0 && !_isResending;

    if (_isResending) return _centredLine('Sending a new code...');

    if (canResend) {
      return _centredLine('Resend code', color: GSWColors.textAccent, onTap: _resendCode);
    }

    return _centredLine('Resend code in 0:${_resendSeconds.toString().padLeft(2, '0')}');
  }

  /// "Didn't get the code?" (SMS version of Figma "Not on WhatsApp?").
  void _showCodeHelpSheet() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: GSWColors.scrim,
      enableDrag: false,
      builder: (_) => GSWSheetDragDismiss(
        child: Builder(builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + bottomInset),
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
                  "Didn't get the code?",
                  style: GSWTextStyles.titleLarge.copyWith(height: 1, color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 8),

                Text(
                  'We sent it by SMS to ${_formatPhone(_pendingPhone ?? '')}. Codes usually '
                  'arrive within a minute. Signal and some message filters can slow them down.',
                  style: GSWTextStyles.bodyMedium.copyWith(
                    height: 20 / 14,
                    color: GSWColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 20),

                ValueListenableBuilder<int>(
                  valueListenable: _resendNotifier,
                  builder: (context, seconds, _) {
                    final canResend = seconds == 0 && !_isResending;

                    return GSWButton(
                      label: canResend
                          ? 'Send a new code'
                          : 'Send a new code in 0:${seconds.toString().padLeft(2, '0')}',
                      variant: canResend ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
                      onPressed: canResend
                          ? () {
                              Navigator.of(sheetContext).pop();
                              _resendCode();
                            }
                          : null,
                    );
                  },
                ),

                const SizedBox(height: 20),

                GSWButton(
                  label: 'Use a different number',
                  variant: GSWButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _changeNumberAgain();
                  },
                ),

                const SizedBox(height: 20),

                GSWButton(
                  label: 'Close',
                  variant: GSWButtonVariant.tertiary,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),

                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      _otpSent ? _buildBackButton() : _buildCloseButton(),

                      const SizedBox(height: 24),

                      Text(
                        _otpSent ? 'Check your messages' : "What's your new number?",

                        style: GSWTextStyles.titleLarge.copyWith(
                          height: _otpSent ? 1 : 30 / 24,
                          color: GSWColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_otpSent)
                        Text.rich(
                          TextSpan(
                            text:
                                'We sent a 6 digit code by SMS to ${_formatPhone(_pendingPhone ?? '')}. ',
                            children: [
                              TextSpan(
                                text: 'Change number',
                                style: const TextStyle(color: GSWColors.textAccent),
                                recognizer: _changeNumberRecognizer,
                              ),
                            ],
                          ),

                          style: GSWTextStyles.bodyMedium.copyWith(
                            height: 20 / 14,
                            color: GSWColors.textSecondary,
                          ),
                        )
                      else
                        Text(
                          widget.currentPhone.trim().isEmpty
                              ? "We'll send a code to it by SMS. Your current number stays "
                                    'on your account until you enter that code.'
                              : "We'll send a code to it by SMS. "
                                    '${_formatPhone(widget.currentPhone)} stays on your account '
                                    'until you enter that code.',

                          style: GSWTextStyles.bodyMedium.copyWith(
                            height: 20 / 14,
                            color: GSWColors.textSecondary,
                          ),
                        ),

                      const SizedBox(height: 24),

                      if (!_otpSent) ...[
                        _buildPhoneInput(),

                        const SizedBox(height: 12),

                        Text(
                          'Your sessions, requests and receipts stay with your account.',

                          style: GSWTextStyles.bodySmall.copyWith(
                            height: 16 / 12,
                            color: GSWColors.textSecondary,
                          ),
                        ),
                      ] else ...[
                        _buildOtpEntry(),

                        const SizedBox(height: 24),

                        // On the number step the field shows the error itself
                        // (errorText), so it is only shown here on the code step.
                        if (_error != null) ...[
                          _centredLine(_error!, color: GSWColors.error),

                          const SizedBox(height: 24),
                        ],

                        _buildResend(),

                        const SizedBox(height: 24),

                        _centredLine(
                          "Didn't get the code?",
                          color: GSWColors.textAccent,
                          onTap: _isSubmitting ? null : _showCodeHelpSheet,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            if (_otpSent)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),

                child: _centredLine(
                  _isSubmitting
                      ? 'Checking your code...'
                      : 'The code fills in on its own once it arrives.',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),

                child: GSWButton(
                  label: 'Send code',

                  onPressed: _isSubmitting
                      ? null
                      : _isPhoneValid
                      ? _sendCode
                      : null,

                  variant: _isSubmitting || !_isPhoneValid
                      ? GSWButtonVariant.disabled
                      : GSWButtonVariant.primary,

                  size: GSWButtonSize.large,

                  isLoading: _isSubmitting,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required Widget icon, required VoidCallback? onTap, required String label}) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: onTap,

          customBorder: const CircleBorder(),

          child: Container(
            width: 46,

            height: 46,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              border: Border.all(color: GSWColors.borderSecondary),
            ),

            alignment: Alignment.center,

            child: icon,
          ),
        ),
      ),
    );
  }

  /// 12.2d: the number step closes the flow (X).
  Widget _buildCloseButton() {
    return _circleButton(
      label: 'Close',
      onTap: () {
        if (context.canPop()) {
          context.pop(false);
        }
      },
      icon: SvgPicture.asset(
        GSWIcons.close,
        width: 12,
        height: 12,
        colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
      ),
    );
  }

  /// 12.2e: back from the code step returns to the number step.
  Widget _buildBackButton() {
    return _circleButton(
      label: 'Back',
      onTap: _isSubmitting ? null : _changeNumberAgain,
      icon: SvgPicture.asset(
        GSWIcons.arrowheadLeft,
        width: 30,
        height: 30,
        colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
      ),
    );
  }

  void _syncCountryField() {
    _countryController.text = '${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}';
  }

  void _handlePhoneChanged() {
    if (_error != null) {
      setState(() {
        _error = null;
      });

      return;
    }

    setState(() {});
  }

  IsoCode? get _selectedIsoCode {
    try {
      return IsoCode.fromJson(_selectedCountry.countryCode);
    } catch (_) {
      return null;
    }
  }

  int get _maxPhoneDigits {
    final isoCode = _selectedIsoCode;

    if (isoCode == null) return 15;

    final lengths = metadataLenghtsByIsoCode[isoCode]?.mobile ?? const <int>[];

    if (lengths.isEmpty) return 15;

    var maximum = lengths.first;

    for (final length in lengths) {
      if (length > maximum) maximum = length;
    }

    return maximum;
  }

  void _handlePhoneInputChanged(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    final maxDigits = _maxPhoneDigits;

    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    if (_phoneController.text != digits) {
      _phoneController.value = TextEditingValue(
        text: digits,

        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    if (_error != null) {
      setState(() {
        _error = null;
      });
    } else {
      setState(() {});
    }
  }

  PhoneNumber? get _parsedPhoneNumber {
    final value = _phoneController.text.trim();

    final isoCode = _selectedIsoCode;

    if (value.isEmpty || isoCode == null) return null;

    try {
      return PhoneNumber.parse(value, destinationCountry: isoCode);
    } catch (_) {
      return null;
    }
  }

  bool get _isPhoneValid {
    final phone = _parsedPhoneNumber;

    return phone != null && phone.isValid(type: PhoneNumberType.mobile);
  }

  String? get _fullPhoneNumber {
    final phone = _parsedPhoneNumber;

    if (phone == null || !phone.isValid(type: PhoneNumberType.mobile)) {
      return null;
    }

    return '+${phone.countryCode}${phone.nsn}';
  }

  String _normalizePhone(String value) {
    return value.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  }

  Widget _buildPhoneInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        CompositedTransformTarget(
          link: _countryLayerLink,

          child: GestureDetector(
            behavior: HitTestBehavior.opaque,

            onTap: _showCountryPicker,

            child: SizedBox(
              width: 120,

              child: Stack(
                alignment: Alignment.centerRight,

                children: [
                  IgnorePointer(
                    child: GSWTextField(
                      size: GSWTextFieldSize.large,

                      controller: _countryController,
                    ),
                  ),

                  const Positioned(
                    right: 12,

                    child: IgnorePointer(
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,

                        size: 18,

                        color: GSWColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: GSWTextField(
            size: GSWTextFieldSize.large,

            controller: _phoneController,

            hintText: _selectedCountry.countryCode == 'AE'
                ? '50 123 4567'
                : _selectedCountry.example,

            keyboardType: TextInputType.number,

            textInputAction: TextInputAction.done,

            errorText: _error,

            onChanged: _handlePhoneInputChanged,

            onComplete: (_) {
              if (_isPhoneValid && !_isSubmitting) {
                _sendCode();
              }
            },
          ),
        ),
      ],
    );
  }

  void _showCountryPicker() {
    FocusScope.of(context).unfocus();

    if (_countryOverlayEntry != null) {
      _hideCountryPicker();

      return;
    }

    final overlay = Overlay.of(context);

    _countryOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final screenWidth = MediaQuery.sizeOf(overlayContext).width;

        final dropdownWidth = screenWidth - 32 > 320 ? 320.0 : screenWidth - 32;

        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,

                onTap: _hideCountryPicker,

                child: const SizedBox.expand(),
              ),

              CompositedTransformFollower(
                link: _countryLayerLink,

                showWhenUnlinked: false,

                offset: const Offset(0, 52),

                child: Material(
                  color: GSWColors.surfacePrimary,

                  elevation: 8,

                  surfaceTintColor: Colors.transparent,

                  clipBehavior: Clip.antiAlias,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GSWRadius.control),

                    side: BorderSide(color: GSWColors.borderSecondary),
                  ),

                  child: SizedBox(
                    width: dropdownWidth,

                    height: 400,

                    child: _CountryPickerDropdown(
                      countries: _countries,

                      onSelected: _selectCountry,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_countryOverlayEntry!);
  }

  void _hideCountryPicker() {
    _countryOverlayEntry?.remove();

    _countryOverlayEntry = null;
  }

  void _selectCountry(Country country) {
    _hideCountryPicker();

    if (!mounted) return;

    setState(() {
      _selectedCountry = country;

      _syncCountryField();

      _phoneController.clear();

      _error = null;
    });
  }

  String _formatPhone(String value) {
    if (value.trim().isEmpty) return value;

    try {
      final phone = PhoneNumber.parse(value);

      return '+${phone.countryCode} ${phone.nsn}';
    } catch (_) {
      return value;
    }
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'credential-already-in-use':
      case 'phone-number-already-exists':
        return 'That mobile number is already linked to another account.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please try again later.';
      case 'session-expired':
      case 'code-expired':
        return 'That code has expired. Request a new code and try again.';
      case 'invalid-verification-code':
        return 'That code is not correct. Check it and try again.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your number.';
      default:
        return error.message ?? 'We could not verify this number. Please try again.';
    }
  }
}

class _CountryPickerDropdown extends StatefulWidget {
  const _CountryPickerDropdown({required this.countries, required this.onSelected});

  final List<Country> countries;

  final ValueChanged<Country> onSelected;

  @override
  State<_CountryPickerDropdown> createState() => _CountryPickerDropdownState();
}

class _CountryPickerDropdownState extends State<_CountryPickerDropdown> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<Country> get _filteredCountries {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) return widget.countries;

    final phoneQuery = query.replaceAll('+', '');

    return widget.countries.where((country) {
      return country.name.toLowerCase().contains(query) ||
          country.countryCode.toLowerCase().contains(query) ||
          country.phoneCode.contains(phoneQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final countries = _filteredCountries;

    return Padding(
      padding: const EdgeInsets.all(12),

      child: Column(
        children: [
          GSWTextField(
            size: GSWTextFieldSize.medium,

            controller: _searchController,

            hintText: 'Search country or code',

            keyboardType: TextInputType.text,

            textInputAction: TextInputAction.search,

            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
          ),

          const SizedBox(height: 8),

          Expanded(
            child: countries.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',

                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,

                    physics: const ClampingScrollPhysics(),

                    itemCount: countries.length,

                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: GSWColors.borderSecondary),

                    itemBuilder: (context, index) {
                      final country = countries[index];

                      return InkWell(
                        onTap: () => widget.onSelected(country),

                        borderRadius: BorderRadius.circular(GSWRadius.inner),

                        child: SizedBox(
                          height: 48,

                          child: Row(
                            children: [
                              Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  country.name,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: GSWTextStyles.bodyMedium.copyWith(
                                    color: GSWColors.textPrimary,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              Text(
                                '+${country.phoneCode}',

                                style: GSWTextStyles.bodyMedium.copyWith(
                                  color: GSWColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
