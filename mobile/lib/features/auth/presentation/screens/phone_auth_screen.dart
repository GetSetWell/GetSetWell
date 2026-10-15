import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/legal/presentation/widgets/legal_agreement_text.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../data/services/firebase_phone_verification_service.dart';
import '../../data/services/phone_auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({
    super.key,
    required this.onClose,
    required this.onOtpSent,
  });

  /// Close returns to exactly where authentication was opened from.
  final VoidCallback onClose;

  /// Called after Firebase sends the SMS code (or verifies the number
  /// instantly on Android). Receives the complete E.164 phone number.
  final void Function(String phone, PhoneOtpRequest request) onOtpSent;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _countryController = TextEditingController();

  late final CountryService _countryService;
  late final List<Country> _countries;

  late Country _selectedCountry;

  final LayerLink _countryLayerLink = LayerLink();

  OverlayEntry? _countryOverlayEntry;

  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _countryService = CountryService();

    _countries = _countryService.getAll()..sort((a, b) => a.name.compareTo(b.name));

    _selectedCountry = _countryService.findByCode('AE')!;

    _syncCountryField();

    _phoneController.addListener(_handlePhoneChanged);
  }

  @override
  void dispose() {
    _hideCountryPicker();

    _phoneController.removeListener(_handlePhoneChanged);

    _phoneController.dispose();
    _countryController.dispose();

    super.dispose();
  }

  void _syncCountryField() {
    _countryController.text = '+${_selectedCountry.phoneCode}';
  }

  void _handlePhoneChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });

      return;
    }

    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // PHONE VALIDATION
  // ---------------------------------------------------------------------------

  IsoCode? get _selectedIsoCode {
    try {
      return IsoCode.fromJson(_selectedCountry.countryCode);
    } catch (_) {
      return null;
    }
  }

  int get _maxPhoneDigits {
    final isoCode = _selectedIsoCode;

    if (isoCode == null) {
      return 15;
    }

    final lengths = metadataLenghtsByIsoCode[isoCode]?.mobile ?? const <int>[];

    if (lengths.isEmpty) {
      return 15;
    }

    var maximum = lengths.first;

    for (final length in lengths) {
      if (length > maximum) {
        maximum = length;
      }
    }

    return maximum;
  }

  void _handlePhoneInputChanged(String value) {
    // Spaces and dashes are accepted and dropped. A leading zero (the way
    // UAE numbers are often written, 050...) is allowed one extra digit.
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    final maxDigits = _maxPhoneDigits + (digits.startsWith('0') ? 1 : 0);

    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    if (_phoneController.text != digits) {
      _phoneController.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    } else {
      setState(() {});
    }
  }

  PhoneNumber? get _parsedPhoneNumber {
    final value = _phoneController.text.trim();

    final isoCode = _selectedIsoCode;

    if (value.isEmpty || isoCode == null) {
      return null;
    }

    try {
      return PhoneNumber.parse(value, destinationCountry: isoCode);
    } catch (_) {
      return null;
    }
  }

  bool get _isPhoneValid {
    final phone = _parsedPhoneNumber;

    if (phone == null) {
      return false;
    }

    return phone.isValid(type: PhoneNumberType.mobile);
  }

  String? get _fullPhoneNumber {
    final phone = _parsedPhoneNumber;

    if (phone == null) {
      return null;
    }

    if (!phone.isValid(type: PhoneNumberType.mobile)) {
      return null;
    }

    return '+${phone.countryCode}${phone.nsn}';
  }

  bool get _canContinue {
    return _isPhoneValid && !_isSending;
  }

  Future<void> _continue() async {
    if (!_canContinue) return;

    final phone = _fullPhoneNumber;

    if (phone == null) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final request = await _phoneAuthService.sendOtp(phone: phone);

      if (!mounted) return;

      if (!request.autoVerified && request.verificationId.isEmpty) {
        throw StateError('Firebase verification ID is missing.');
      }

      widget.onOtpSent(phone, request);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to send OTP: $error');
      }

      if (!mounted) return;

      setState(() {
        _errorMessage = _sendErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _sendErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'That number does not look right. Check it and try again.';

        case 'too-many-requests':
        case 'quota-exceeded':
          return 'Too many codes asked for. Wait a few minutes, then try again.';

        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
      }
    }

    return 'We could not send the code by SMS. Please try again.';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCloseButton(),

                      const SizedBox(height: 32),

                      _buildHeader(),

                      const SizedBox(height: 32),

                      _buildPhoneInput(),

                      const SizedBox(height: 12),

                      // 12.5c: terms are linked here, agreement is recorded
                      // by the checkbox on Your details.
                      const LegalAgreementText(),
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

  // ---------------------------------------------------------------------------
  // CLOSE
  // ---------------------------------------------------------------------------

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: GSWColors.borderSecondary)),
      child: InkWell(
        onTap: widget.onClose,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: SvgPicture.asset(
              GSWIcons.close,
              width: 12,
              height: 12,
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your number?",
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),

        const SizedBox(height: 12),

        Text(
          'We send your code by SMS, then use this number '
          'to confirm your sessions. No password to remember.',
          style: GSWTextStyles.bodyMedium.copyWith(
            color: GSWColors.textSecondary,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PHONE
  // ---------------------------------------------------------------------------

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
              width: 96,
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
                    right: 8,
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

            // Phone keypad. Spaces and dashes are stripped on input.
            keyboardType: TextInputType.phone,

            textInputAction: TextInputAction.done,

            errorText: _errorMessage,

            onChanged: _handlePhoneInputChanged,

            onComplete: (_) {
              if (_canContinue) {
                _continue();
              }
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // COUNTRY PICKER
  // ---------------------------------------------------------------------------

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
              // Tap outside to close.
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

      // Clear old number because its
      // length/pattern belongs to the
      // previously selected country.
      _phoneController.clear();

      _errorMessage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // BOTTOM
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: GSWButton(
        size: GSWButtonSize.large,
        variant: _canContinue ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
        label: 'Continue',
        isLoading: _isSending,
        onPressed: _canContinue ? _continue : null,
      ),
    );
  }
}

// =============================================================================
// COUNTRY PICKER DROPDOWN
// =============================================================================

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

    if (query.isEmpty) {
      return widget.countries;
    }

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
                        onTap: () {
                          widget.onSelected(country);
                        },
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
