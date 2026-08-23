import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/inputs/gsw_checkbox.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_area.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';
import 'package:mobile/features/booking/domain/validators/uae_phone_validator.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/training_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HelpMeChooseScreen extends StatefulWidget {
  const HelpMeChooseScreen({super.key});

  @override
  State<HelpMeChooseScreen> createState() => _HelpMeChooseScreenState();
}

class _HelpMeChooseScreenState extends State<HelpMeChooseScreen> {
  int _currentStep = 1;
  String? _selectedGoal;

  final Set<String> _selectedDays = {};
  List<String> _availableLanguages = [];
  List<int> _availablePrices = [];
  List<TrainingLocation> _availableTrainingLocations = [];

  late final TrainerRepository _trainerRepository;

  String? _selectedTime;
  TrainingLocation? _selectedLocation;
  String? _selectedTrainerPreference;
  String? _selectedBudget;
  String? _selectedLanguage;
  final TextEditingController _preferredAreaController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsAppController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _shareDetailsConsent = false;
  bool _showPhoneError = false;

  String? _trainerGenderValue() {
    switch (_selectedTrainerPreference) {
      case 'Male':
        return 'male';
      case 'Female':
        return 'female';
      case 'No preference':
      case null:
        return null;
      default:
        return null;
    }
  }

  ({int? min, int? max}) _budgetRange() {
    if (_selectedBudget == null || _selectedBudget == 'No preference') {
      return (min: null, max: null);
    }

    final matches = RegExp(
      r'\d+',
    ).allMatches(_selectedBudget!).map((match) => int.parse(match.group(0)!)).toList();

    if (matches.length < 2) {
      return (min: null, max: null);
    }

    return (min: matches[0], max: matches[1]);
  }

  @override
  void initState() {
    super.initState();

    _trainerRepository = TrainerRepository(Supabase.instance.client);

    _loadMatchingOptions();
  }

  Future<void> _loadMatchingOptions() async {
    try {
      final languages = await _trainerRepository.getAvailableLanguages();

      final prices = await _trainerRepository.getAvailablePrices();

      final locations = await _trainerRepository.getAvailableTrainingLocations();

      if (!mounted) return;

      setState(() {
        _availableLanguages = languages;
        _availablePrices = prices;
        _availableTrainingLocations = locations;
      });
    } catch (error) {
      debugPrint('Failed to load matching options: $error');
    }
  }

  List<String> get _availableBudgetOptions {
    final bands = <String>{};

    for (final price in _availablePrices) {
      final lower = (price ~/ 100) * 100;
      final upper = lower + 99;

      bands.add('AED $lower–$upper');
    }

    return [...bands, 'No preference'];
  }

  @override
  void dispose() {
    _preferredAreaController.dispose();
    _nameController.dispose();
    _whatsAppController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const List<String> _goalOptions = [
    'Build strength',
    'Lose weight',
    'Start again after a break',
    'Improve mobility',
    'Yoga or pilates',
    'Pre or postnatal',
    'Not sure yet',
  ];

  void _goNext() {
    if (_currentStep >= 4) return;

    setState(() {
      _currentStep++;
    });
  }

  void _goBack() {
    if (_currentStep <= 1) return;

    setState(() {
      _currentStep--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        left: false,
        right: false,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            _buildProgressHeader(),

            Expanded(child: _buildCurrentStep()),

            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  ConciergeMatchPayload _buildRequestPayload() {
    final budget = _budgetRange();

    return ConciergeMatchPayload(
      customerName: _nameController.text,

      phone: UAEPhoneValidator.toE164(_whatsAppController.text),

      goal: _selectedGoal!,

      preferredDays: _selectedDays.map((day) => day.toLowerCase()).toList(),

      preferredTime: _selectedTime!.toLowerCase(),

      trainingLocationId: _selectedLocation!.id,
      preferredArea: _preferredAreaController.text,

      trainerGenderPreference: _trainerGenderValue(),

      budgetMin: budget.min,
      budgetMax: budget.max,

      languagePreference: _selectedLanguage == null || _selectedLanguage == 'No preference'
          ? null
          : _selectedLanguage,

      message: _notesController.text,

      shareDetailsConsent: _shareDetailsConsent,
    );
  }

  Widget _buildTrainingLocationOptions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableTrainingLocations.map((location) {
        final isSelected = _selectedLocation?.id == location.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedLocation = location;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? GSWColors.borderFocused : GSWColors.borderSecondary,
              ),
            ),
            child: Text(
              location.name,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GSWColors.borderSecondary),
              ),
              child: SvgPicture.asset(
                GSWIcons.close,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: _currentStep / 4,
                minHeight: 8,
                backgroundColor: GSWColors.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation<Color>(GSWColors.primary),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            '$_currentStep of 4',
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_currentStep) {
      1 => _buildStepOne(),
      2 => _buildStepTwo(),
      3 => _buildStepThree(),
      4 => _buildStepFour(),
      _ => _buildStepOne(),
    };
  }

  Widget _buildDayOptions() {
    const days = <String, String>{
      'Monday': 'Mo',
      'Tuesday': 'Tu',
      'Wednesday': 'We',
      'Thursday': 'Th',
      'Friday': 'Fr',
      'Saturday': 'Sa',
      'Sunday': 'Su',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.entries.map((entry) {
        final day = entry.key;
        final shortDay = entry.value;
        final isSelected = _selectedDays.contains(day);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(day);
              } else {
                _selectedDays.add(day);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
              border: Border.all(
                color: isSelected ? GSWColors.borderFocused : GSWColors.borderSecondary,
              ),
            ),
            child: Text(
              shortDay,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalOption(String goal) {
    final isSelected = _selectedGoal == goal;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = goal;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? GSWColors.primary : GSWColors.borderSecondary),
        ),
        child: Text(
          goal,
          style: GSWTextStyles.labelLarge.copyWith(
            color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleSelectOptions({
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValue == option;

        return GestureDetector(
          onTap: () => onSelected(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? GSWColors.borderFocused : GSWColors.borderSecondary,
              ),
            ),
            child: Text(
              option,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionalSelectOptions({
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValue == option;

        return GestureDetector(
          onTap: () {
            onSelected(isSelected ? null : option);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? GSWColors.borderFocused : GSWColors.borderSecondary,
              ),
            ),
            child: Text(
              option,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool accent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary)),

        const SizedBox(height: 4),

        Text(
          value,
          style: GSWTextStyles.bodyMedium.copyWith(
            color: accent ? GSWColors.textAccent : GSWColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _summaryGoalLabel(String? goal) {
    switch (goal) {
      case 'Start again after a break':
        return 'Start again';

      case 'Pre or postnatal':
        return 'Pre/postnatal';

      case null:
        return '';

      default:
        return goal;
    }
  }

  Widget _buildRequestSummary() {
    final days = _selectedDays
        .map((day) {
          const abbreviations = {
            'Monday': 'Mon',
            'Tuesday': 'Tue',
            'Wednesday': 'Wed',
            'Thursday': 'Thu',
            'Friday': 'Fri',
            'Saturday': 'Sat',
            'Sunday': 'Sun',
          };

          return abbreviations[day] ?? day;
        })
        .join(', ');

    String trainerPreference = '';

    if (_selectedTrainerPreference != null) {
      trainerPreference = _selectedTrainerPreference!;
    }

    if (_selectedBudget != null) {
      if (trainerPreference.isNotEmpty) {
        trainerPreference += ', ';
      }

      trainerPreference += 'AED ${_selectedBudget!}';
    }

    if (trainerPreference.isEmpty) {
      trainerPreference = 'No preference';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your request',
                  style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textSecondary),
                ),
              ),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      'Edit',
                      style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textAccent),
                    ),

                    const SizedBox(width: 8),

                    SvgPicture.asset(
                      GSWIcons.edit,
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: GSWColors.borderDisabled),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSummaryItem('Goal', _summaryGoalLabel(_selectedGoal))),

              const SizedBox(width: 12),

              Expanded(child: _buildSummaryItem('Days', days)),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSummaryItem('Time', _selectedTime ?? '')),

              const SizedBox(width: 12),

              Expanded(child: _buildSummaryItem('Where', _selectedLocation?.name ?? '')),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSummaryItem('Preferred Area', _preferredAreaController.text.trim()),
              ),

              const SizedBox(width: 12),

              Expanded(child: _buildSummaryItem('Trainer', trainerPreference, accent: true)),
            ],
          ),
        ],
      ),
    );
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 1:
        return _selectedGoal != null;

      case 2:
        return _selectedDays.isNotEmpty &&
            _selectedTime != null &&
            _selectedLocation != null &&
            _preferredAreaController.text.trim().isNotEmpty;

      case 3:
        return true;

      case 4:
        return _nameController.text.trim().isNotEmpty &&
            UAEPhoneValidator.isValid(_whatsAppController.text) &&
            _shareDetailsConsent;

      default:
        return false;
    }
  }

  Widget _buildStepOne() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary, height: 1),
              children: [
                const TextSpan(text: 'WHAT ARE YOU\n'),
                TextSpan(
                  text: 'LOOKING FOR?',
                  style: GSWTextStyles.displayLarge.copyWith(
                    color: GSWColors.textAccent,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Four quick questions, it’ll only take about a minute.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 24),

          ..._goalOptions.map(
            (goal) =>
                Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildGoalOption(goal)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                children: [
                  const TextSpan(text: 'WHEN AND WHERE\n'),
                  TextSpan(
                    text: 'CAN YOU TRAIN?',
                    style: GSWTextStyles.displayLarge.copyWith(
                      color: GSWColors.textAccent,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Days that work',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            _buildDayOptions(),

            const SizedBox(height: 24),

            Text(
              'Time of day',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            _buildSingleSelectOptions(
              options: const ['Morning', 'Afternoon', 'Evening'],
              selectedValue: _selectedTime,
              onSelected: (value) {
                setState(() {
                  _selectedTime = value;
                });
              },
            ),

            const SizedBox(height: 24),

            Text('Where', style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary)),

            const SizedBox(height: 8),

            _buildTrainingLocationOptions(),

            const SizedBox(height: 24),

            Text(
              'Preferred area',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            GSWTextField(
              size: GSWTextFieldSize.large,
              controller: _preferredAreaController,
              hintText: 'Dubai Marina',
              leadingIcon: GSWIcons.location,
              onChanged: (_) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepThree() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary),
                children: [
                  const TextSpan(text: 'ANY '),
                  TextSpan(
                    text: 'PREFERENCES?',
                    style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textAccent),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Optional. It just helps us narrow things down.',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 24),

            Text(
              'Trainer preference',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            _buildOptionalSelectOptions(
              options: const ['Male', 'Female', 'No preference'],
              selectedValue: _selectedTrainerPreference,
              onSelected: (value) {
                setState(() {
                  _selectedTrainerPreference = value;
                });
              },
            ),

            const SizedBox(height: 24),

            Text(
              'How much do you want to spend per session?',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            _buildOptionalSelectOptions(
              options: _availableBudgetOptions,
              selectedValue: _selectedBudget,
              onSelected: (value) {
                setState(() {
                  _selectedBudget = value;
                });
              },
            ),

            const SizedBox(height: 8),

            Text(
              'A guide only. We show exact rates before anything is agreed.',
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 24),

            Text(
              'Language you would prefer',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            _buildOptionalSelectOptions(
              options: [..._availableLanguages, 'No preference'],
              selectedValue: _selectedLanguage,
              onSelected: (value) {
                setState(() {
                  _selectedLanguage = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepFour() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary),
                children: [
                  const TextSpan(text: 'LAST BIT. HOW CAN\nWE '),
                  TextSpan(
                    text: 'REACH YOU?',
                    style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textAccent),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildRequestSummary(),

            const SizedBox(height: 24),

            GSWTextField(
              size: GSWTextFieldSize.large,
              controller: _nameController,
              label: 'Full name',
              hintText: 'Your name',
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 24),

            Text(
              'WhatsApp number',
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GSWColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GSWColors.borderSecondary),
                  ),
                  child: Text(
                    '+971',
                    style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: GSWTextField(
                    size: GSWTextFieldSize.large,
                    controller: _whatsAppController,
                    hintText: '50 123 4567',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,

                    errorText:
                        _showPhoneError && !UAEPhoneValidator.isValid(_whatsAppController.text)
                        ? 'Enter a valid UAE mobile number'
                        : null,

                    onChanged: (_) {
                      setState(() {
                        if (_showPhoneError) {
                          _showPhoneError = !UAEPhoneValidator.isValid(_whatsAppController.text);
                        }
                      });
                    },

                    onComplete: (_) {
                      setState(() {
                        _showPhoneError = !UAEPhoneValidator.isValid(_whatsAppController.text);
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            GSWTextArea(
              size: GSWTextAreaSize.large,
              controller: _notesController,
              label: 'Anything else we should know?',
              hintText: 'Optional...',
              helpingText: 'Please do not include detailed medical information here.',
              maxLength: 250,
              onChanged: (_) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitRequest() {
    final payload = _buildRequestPayload();

    debugPrint('Help me choose payload: ${payload.toJson()}');
  }

  Widget _buildBottomActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(color: GSWColors.backgroundSecondary),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentStep == 4) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: GSWCheckbox(
                    value: _shareDetailsConsent,
                    size: 24,
                    iconSize: 14,
                    onChanged: (value) {
                      setState(() {
                        _shareDetailsConsent = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'I agree to share my details with GetSetWell and the trainer '
                    'they match me with so they can respond to my request.',
                    style: GSWTextStyles.bodySmall.copyWith(
                      color: GSWColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
          ],
          GSWButton(
            variant: _currentStep == 1 ? GSWButtonVariant.disabled : GSWButtonVariant.secondary,
            size: GSWButtonSize.medium,
            label: 'Back',
            onPressed: _currentStep == 1 ? null : _goBack,
          ),

          const SizedBox(height: 8),

          GSWButton(
            variant: _canContinue ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
            size: GSWButtonSize.medium,
            label: _currentStep == 4 ? 'Send Request' : 'Continue',
            onPressed: !_canContinue
                ? null
                : _currentStep == 4
                ? _submitRequest
                : _goNext,
          ),
        ],
      ),
    );
  }
}
