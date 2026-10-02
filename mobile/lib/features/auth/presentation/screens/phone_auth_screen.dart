import 'package:country_picker/country_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/legal/presentation/widgets/legal_agreement_text.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../data/services/phone_auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({
    super.key,
    required this.onClose,
    required this.onOtpSent,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  /// Close returns to exactly where authentication was opened from.
  final VoidCallback onClose;

  /// Called after Supabase successfully sends the OTP.
  /// Receives the complete E.164 phone number.
  final ValueChanged<String> onOtpSent;

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

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

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _countryService = CountryService();

    _countries = _countryService.getAll()
      ..sort((a, b) => a.name.compareTo(b.name));

    _selectedCountry = _countryService.findByCode('AE')!;

    _syncCountryField();

    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onTermsTap;

    _privacyRecognizer = TapGestureRecognizer()..onTap = widget.onPrivacyTap;

    _phoneController.addListener(_handlePhoneChanged);
  }

  @override
  void dispose() {
    _hideCountryPicker();

    _phoneController.removeListener(_handlePhoneChanged);

    _phoneController.dispose();
    _countryController.dispose();

    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();

    super.dispose();
  }

  void _syncCountryField() {
    _countryController.text =
        '${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}';
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
      await _phoneAuthService.sendOtp(phone: phone);

      if (!mounted) return;

      widget.onOtpSent(phone);
    } catch (error) {
      debugPrint('Failed to send OTP: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not send the code. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCloseButton(),

                      const SizedBox(height: 32),

                      _buildHeader(),

                      const SizedBox(height: 32),

                      _buildPhoneInput(),

                      const SizedBox(height: 10),

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
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Icon(Icons.close, size: 22, color: GSWColors.primary),
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
          "WHAT'S YOUR NUMBER?",
          style: GSWTextStyles.displaySmall.copyWith(
            color: GSWColors.textPrimary,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'We send your code on WhatsApp, then use this number '
          'to confirm your sessions. No password to remember.',
          style: GSWTextStyles.bodyMedium.copyWith(
            color: GSWColors.textSecondary,
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

            // Numeric keyboard only.
            keyboardType: TextInputType.number,

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
                    borderRadius: BorderRadius.circular(12),
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
        variant: _canContinue
            ? GSWButtonVariant.primary
            : GSWButtonVariant.disabled,
        label: _isSending ? 'Sending...' : 'Continue',
        onPressed: _canContinue ? _continue : null,
      ),
    );
  }
}

// =============================================================================
// COUNTRY PICKER DROPDOWN
// =============================================================================

class _CountryPickerDropdown extends StatefulWidget {
  const _CountryPickerDropdown({
    required this.countries,
    required this.onSelected,
  });

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
                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: GSWColors.textSecondary,
                      ),
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
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              Text(
                                country.flagEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),

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
