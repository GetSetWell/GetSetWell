import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/buttons/gsw_toggle.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_area.dart';
import 'package:mobile/core/widgets/inputs/gsw_text_field.dart';
import 'package:mobile/features/auth/domain/model/auth_flow_intent.dart';
import 'package:mobile/features/auth/presentation/navigation/auth_flow_resolver.dart';
import 'package:mobile/features/booking/data/services/active_concierge_match_service.dart';
import 'package:mobile/features/booking/domain/models/concierge_match_payload.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_ui.dart';
import 'package:mobile/features/matching/presentation/widgets/open_request_limit_sheet.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/training_location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HelpMeChooseScreen extends StatefulWidget {
  const HelpMeChooseScreen({super.key, this.requireAuth = false});

  final bool requireAuth;

  @override
  State<HelpMeChooseScreen> createState() => _HelpMeChooseScreenState();
}

class _HelpMeChooseScreenState extends State<HelpMeChooseScreen> {
  int _currentStep = 1;
  bool _showFemaleOnly = false;
  bool _isSubmitting = false;

  String? _selectedGoal;

  final Set<String> _selectedDays = {};
  String? _selectedTime;

  TrainingLocation? _selectedLocation;
  final TextEditingController _preferredAreaController = TextEditingController();

  List<String> _availableLanguages = [];
  List<int> _availablePrices = [];
  List<TrainingLocation> _availableTrainingLocations = [];
  Set<String> _availableSpecialtySlugs = {};

  String? _selectedLanguage;

  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _goalOptionsLoadFailed = false;

  double? _budgetMinValue;
  double? _budgetMaxValue;

  late final TrainerRepository _trainerRepository;

  static const List<_GoalDefinition> _goalDefinitions = [
    _GoalDefinition(
      label: 'Get stronger',
      specialtySlugs: {'core-strength', 'strength', 'strength-training'},
    ),
    _GoalDefinition(label: 'Lose weight', specialtySlugs: {'weight-loss', 'fat-loss'}),
    _GoalDefinition(
      label: 'Move better',
      specialtySlugs: {'mobility', 'beginner-yoga', 'yoga', 'pilates'},
    ),
    _GoalDefinition(label: 'Back after a break', alwaysAvailable: true),
    _GoalDefinition(
      label: 'Pre or postnatal',
      specialtySlugs: {'pre-postnatal', 'postnatal', 'prenatal'},
    ),
    _GoalDefinition(label: 'Something else', alwaysAvailable: true),
  ];

  @override
  void initState() {
    super.initState();

    _trainerRepository = TrainerRepository(Supabase.instance.client);

    _loadOptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _askForMatchNotifications();
    });
  }

  @override
  void dispose() {
    _preferredAreaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        _trainerRepository.getAvailableLanguages(),
        _trainerRepository.getAvailablePrices(),
        _trainerRepository.getAvailableTrainingLocations(),
        _trainerRepository.getAvailableSpecialtySlugs(),
      ]);

      if (!mounted) return;

      final languages = results[0] as List<String>;
      final prices = results[1] as List<int>;
      final locations = results[2] as List<TrainingLocation>;
      final specialtySlugs = results[3] as Set<String>;

      final sortedPrices = prices.toSet().toList()..sort();

      setState(() {
        _availableLanguages = languages;
        _availablePrices = sortedPrices;
        _availableTrainingLocations = locations;
        _availableSpecialtySlugs = specialtySlugs;
        if (sortedPrices.isNotEmpty) {
          _budgetMinValue = sortedPrices.first.toDouble();
          _budgetMaxValue = sortedPrices.last.toDouble();
        }

        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load Help Me Choose options: $error');

      if (!mounted) return;

      setState(() {
        _goalOptionsLoadFailed = true;
        _isLoading = false;
      });
    }
  }

  void _retryLoadOptions() {
    setState(() {
      _goalOptionsLoadFailed = false;
      _isLoading = true;
    });

    _loadOptions();
  }

  // ---------------------------------------------------------------------------
  // BACKEND-DERIVED OPTIONS
  // ---------------------------------------------------------------------------

  List<_GoalDefinition> get _goalOptions {
    if (_goalOptionsLoadFailed || _availableSpecialtySlugs.isEmpty) {
      return _goalDefinitions;
    }

    return _goalDefinitions.where((goal) {
      if (goal.alwaysAvailable) {
        return true;
      }

      return goal.specialtySlugs.any(_availableSpecialtySlugs.contains);
    }).toList();
  }

  List<TrainingLocation> get _matchingLocations {
    return _availableTrainingLocations.where((location) {
      final name = location.name.toLowerCase();

      return name.contains('home') || name.contains('gym') || name.contains('outdoor');
    }).toList();
  }

  String _locationLabel(TrainingLocation location) {
    final value = location.name.toLowerCase();

    if (value.contains('home')) {
      return 'Home';
    }

    if (value.contains('gym')) {
      return 'Gym';
    }

    if (value.contains('outdoor')) {
      return 'Outdoors';
    }

    return location.name;
  }

  List<int> get _sortedPrices {
    final prices = _availablePrices.toSet().toList();
    prices.sort();
    return prices;
  }

  int? get _selectedBudgetMin {
    if (_budgetMinValue == null) {
      return null;
    }

    return _roundBudgetValue(_budgetMinValue!);
  }

  int? get _selectedBudgetMax {
    if (_budgetMaxValue == null) {
      return null;
    }

    return _roundBudgetValue(_budgetMaxValue!);
  }

  int _roundBudgetValue(double value) {
    // Keeps the display clean while the slider itself moves smoothly.
    // Example: 247 becomes 245, 253 becomes 255.
    return (value / 5).round() * 5;
  }
  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  void _closeFlow() {
    // Help me choose is normally pushed, but it can be reached with go()
    // (deep link, auth redirect), so never pop an empty stack.
    conciergeSafePop(context);
  }

  void _goBack() {
    if (_currentStep <= 1) return;

    setState(() {
      _currentStep--;
    });
  }

  void _goNext() {
    if (_currentStep >= 4) return;

    setState(() {
      _currentStep++;
    });
  }

  Future<void> _continueFromHelpMeChoose() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final draft = ConciergeMatchPayload(
        goal: _selectedGoal!,
        preferredDays: _selectedDays.toList(),
        preferredTime: _selectedTime!,
        trainingLocationId: _selectedLocation!.id,
        trainingLocationName: _locationLabel(_selectedLocation!),
        // The server accepts up to 100 characters for the area.
        preferredArea: () {
          final area = _preferredAreaController.text.trim();
          return area.length > 100 ? area.substring(0, 100).trim() : area;
        }(),
        budgetMin: _selectedBudgetMin,
        budgetMax: _selectedBudgetMax,
        femaleTrainerOnly: _showFemaleOnly,
        languagePreference: _selectedLanguage,
        message: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      final intent = AuthFlowIntent.conciergeMatch(draft);
      final user = FirebaseAuth.instance.currentUser;

      if (widget.requireAuth) {
        if (!mounted) return;

        await context.push(GSWRoutes.userAuth, extra: intent);

        return;
      }

      if (user != null) {
        // One open Help me choose request at a time (DB rule). Check before
        // submitting so a signed-in customer sees 9.3 instead of an error.
        final canSubmit = await _checkNoOpenRequest();

        if (!canSubmit || !mounted) return;

        await resolveAuthFlow(context, intent);
        return;
      }

      if (!mounted) return;

      await context.push(GSWRoutes.userAuth, extra: intent);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Returns true when there is no open concierge request. Otherwise shows
  /// Figma 9.3 "You already have an open request" and returns false.
  Future<bool> _checkNoOpenRequest() async {
    try {
      final active = await ActiveConciergeMatchService(Supabase.instance.client).getCurrent();

      if (active == null) return true;
      if (!mounted) return false;

      final seeRequests = await OpenRequestLimitSheet.show(context, active);

      if (!mounted) return false;

      if (seeRequests) {
        context.go(GSWRoutes.sessions, extra: 0);
      }

      return false;
    } catch (error) {
      // The server still enforces the limit; let the submit path report it.
      debugPrint('Active concierge request check failed: $error');
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------

  bool get _canContinue {
    switch (_currentStep) {
      case 1:
        return _selectedGoal != null;

      case 2:
        return _selectedDays.isNotEmpty && _selectedTime != null;

      case 3:
        return _selectedLocation != null &&
            _preferredAreaController.text.trim().isNotEmpty &&
            _selectedBudgetMin != null &&
            _selectedBudgetMax != null;

      case 4:
        // Everything on the final step is optional.
        return true;

      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgressHeader(),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: GSWColors.primary))
                  : _buildCurrentStep(),
            ),

            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        children: [
          Material(
            // Figma: black/40 fill with border/secondary ring.
            color: GSWColors.backgroundOverlay,
            shape: const CircleBorder(side: BorderSide(color: GSWColors.borderSecondary)),
            child: InkWell(
              onTap: _closeFlow,
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
          ),

          const SizedBox(width: 16),

          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GSWRadius.full),
              child: LinearProgressIndicator(
                value: _currentStep / 4,
                minHeight: 8,
                backgroundColor: GSWColors.surfaceInteractive,
                valueColor: const AlwaysStoppedAnimation<Color>(GSWColors.primary),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Text(
            '$_currentStep of 4',
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              height: 20 / 14,
            ),
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

  // ---------------------------------------------------------------------------
  // 2.1 YOUR GOAL
  // ---------------------------------------------------------------------------

  Widget _buildStepOne() {
    return _stepScrollView(
      children: [
        Text(
          'What is your goal?',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),

        const SizedBox(height: 24),

        ..._goalOptions.map(
          (goal) =>
              Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildGoalOption(goal)),
        ),
      ],
    );
  }

  Widget _buildGoalOption(_GoalDefinition goal) {
    final selected = _selectedGoal == goal.label;

    return _fullWidthOption(
      label: goal.label,
      selected: selected,
      onTap: () {
        setState(() {
          _selectedGoal = goal.label;
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2.2 WHEN CAN YOU TRAIN?
  // ---------------------------------------------------------------------------

  Widget _buildStepTwo() {
    return _stepScrollView(
      children: [
        Text(
          'When can you train?',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),

        const SizedBox(height: 24),

        Text(
          'Days that work',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),

        const SizedBox(height: 8),

        _buildDayOptions(),

        const SizedBox(height: 24),

        Text(
          'Time of day',
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),

        const SizedBox(height: 8),

        // Figma 2.2: hug-width pills, 24px sides, 8px gap, wrapping.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTimeOption('Morning'),
            _buildTimeOption('Afternoon'),
            _buildTimeOption('Evening'),
          ],
        ),
      ],
    );
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
        final selected = _selectedDays.contains(entry.key);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(GSWRadius.full),
            onTap: () {
              setState(() {
                if (selected) {
                  _selectedDays.remove(entry.key);
                } else {
                  _selectedDays.add(entry.key);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GSWColors.primary : GSWColors.surfaceElevated,
                border: Border.all(
                  width: 1,
                  color: selected ? GSWColors.primary : GSWColors.borderSecondary,
                ),
              ),
              child: Text(
                entry.value,
                style: GSWTextStyles.labelLarge.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeOption(String label) {
    final isSelected = _selectedTime == label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTime = label;
          });
        },
        borderRadius: BorderRadius.circular(GSWRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
            borderRadius: BorderRadius.circular(GSWRadius.full),
            border: Border.all(
              width: 1,
              color: isSelected ? GSWColors.primary : GSWColors.borderSecondary,
            ),
          ),
          // widthFactor 1 keeps the pill hugging its label inside the Wrap.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
  // ---------------------------------------------------------------------------
  // 2.3 WHERE + BUDGET
  // ---------------------------------------------------------------------------

  Widget _buildStepThree() {
    return _stepScrollView(
      children: [
        Text(
          'Where, and what is your budget?',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),

        const SizedBox(height: 24),

        if (_goalOptionsLoadFailed) ...[
          Text(
            "We couldn't load the locations and prices. Check your connection and try again.",
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 16),
          GSWButton(
            size: GSWButtonSize.medium,
            variant: GSWButtonVariant.secondary,
            label: 'Try again',
            onPressed: _retryLoadOptions,
          ),
        ] else ...[
          Text(
            'Where',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
          ),

          const SizedBox(height: 8),

          _buildWhereOptions(),

          const SizedBox(height: 24),

          GSWTextField(
            size: GSWTextFieldSize.large,
            controller: _preferredAreaController,
            label: 'Preferred area',
            hintText: 'e.g. Dubai Marina',
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              setState(() {});
            },
          ),

          const SizedBox(height: 24),

          _buildBudgetSection(),
        ],
      ],
    );
  }

  Widget _buildWhereOptions() {
    final locations = [..._matchingLocations];

    // Keep the exact visual order from Figma.
    const order = {'Home': 0, 'Gym': 1, 'Outdoors': 2};

    locations.sort((a, b) {
      final aLabel = _locationLabel(a);
      final bLabel = _locationLabel(b);

      return (order[aLabel] ?? 99).compareTo(order[bLabel] ?? 99);
    });

    // Figma 2.3: hug-width pills, 24px sides, 8px gap, wrapping.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final location in locations) _buildWhereOption(location)],
    );
  }

  Widget _buildWhereOption(TrainingLocation location) {
    final isSelected = _selectedLocation?.id == location.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLocation = location;
          });
        },
        borderRadius: BorderRadius.circular(GSWRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isSelected ? GSWColors.primary : GSWColors.surfaceElevated,
            borderRadius: BorderRadius.circular(GSWRadius.full),
            border: Border.all(
              width: 1,
              color: isSelected ? GSWColors.primary : GSWColors.borderSecondary,
            ),
          ),
          // widthFactor 1 keeps the pill hugging its label inside the Wrap.
          child: Center(
            widthFactor: 1,
            child: Text(
              _locationLabel(location),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: GSWTextStyles.labelLarge.copyWith(
                color: isSelected ? GSWColors.textInverse : GSWColors.textPrimary,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetSection() {
    final prices = _sortedPrices;

    if (prices.isEmpty || _budgetMinValue == null || _budgetMaxValue == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget per session',
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
          ),

          const SizedBox(height: 12),

          Text(
            'No session prices available',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ],
      );
    }

    final absoluteMin = prices.first.toDouble();

    final absoluteMax = prices.last.toDouble();

    final selectedMin = _selectedBudgetMin ?? prices.first;

    final selectedMax = _selectedBudgetMax ?? prices.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget per session',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
        ),

        const SizedBox(height: 12),

        Text(
          selectedMin == selectedMax ? 'AED $selectedMin' : 'AED $selectedMin to AED $selectedMax',
          style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary, height: 1),
        ),

        const SizedBox(height: 12),

        if (absoluteMin == absoluteMax)
          SizedBox(
            height: 24,
            child: Center(
              child: Container(
                width: double.infinity,
                height: 4,
                decoration: BoxDecoration(
                  color: GSWColors.primary,
                  borderRadius: BorderRadius.circular(GSWRadius.full),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 24,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,

                activeTrackColor: GSWColors.primary,

                inactiveTrackColor: GSWColors.surfaceInteractive,

                thumbColor: GSWColors.primary,

                overlayColor: GSWColors.primary.withValues(alpha: 0.10),

                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 12,
                  elevation: 0,
                  pressedElevation: 0,
                ),

                rangeTrackShape: const EdgeToEdgeRangeSliderTrackShape(),

                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),

                showValueIndicator: ShowValueIndicator.never,
              ),

              child: RangeSlider(
                min: absoluteMin,
                max: absoluteMax,

                // IMPORTANT:
                // No divisions.
                // This makes the slider continuous and smooth.
                values: RangeValues(
                  _budgetMinValue!.clamp(absoluteMin, absoluteMax),
                  _budgetMaxValue!.clamp(absoluteMin, absoluteMax),
                ),

                onChanged: (RangeValues values) {
                  setState(() {
                    _budgetMinValue = values.start;

                    _budgetMaxValue = values.end;
                  });
                },
              ),
            ),
          ),

        const SizedBox(height: 12),

        Text(
          "This is the trainer's session rate. A 5% service fee is added at checkout.",
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 16 / 12),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2.4 ANYTHING ELSE
  // ---------------------------------------------------------------------------

  Widget _buildStepFour() {
    return _stepScrollView(
      children: [
        Text(
          'Anything else we should know?',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),

        const SizedBox(height: 24),

        Text(
          'Trainer',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
        ),

        const SizedBox(height: 12),

        _buildFemaleOnlyToggle(context),

        const SizedBox(height: 24),

        Text(
          'Language',
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
        ),

        const SizedBox(height: 12),

        _buildLanguages(),

        const SizedBox(height: 24),

        // Figma 2.4 uses "Text Area Small": 80px minimum height.
        GSWTextArea(
          size: GSWTextAreaSize.medium,
          controller: _notesController,
          hintText: 'Tell us anything that would help us pick the right person...',
          helpingText: 'A real person reads this.',
          maxLength: 250,
          onChanged: (_) {
            setState(() {});
          },
        ),

        const SizedBox(height: 24),

        Text(
          "Please don't include health details here. "
          "If there's something your trainer should know, you can tell them directly.",
          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 16 / 12),
        ),
      ],
    );
  }

  Widget _buildFemaleOnlyToggle(BuildContext context) {
    return Container(
      width: double.infinity,
      // Figma 2.4: 12px sides, 8px top and bottom around the 24px toggle.
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: GSWColors.backgroundSecondary,
        border: Border.all(color: GSWColors.borderSecondary),
        borderRadius: BorderRadius.circular(GSWRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Show female trainers only',
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textPrimary, height: 16 / 12),
            ),
          ),

          GSWToggle(
            value: _showFemaleOnly,
            onChanged: (value) {
              setState(() {
                _showFemaleOnly = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _askForMatchNotifications() async {
    try {
      await _askForMatchNotificationsUnsafe();
    } catch (error) {
      // Push is optional. Never let a Firebase error break the flow.
      debugPrint('Match notification prompt failed: $error');
    }
  }

  Future<void> _askForMatchNotificationsUnsafe() async {
    final pushService = PushNotificationService();

    if (!await pushService.shouldRequestPermission()) {
      return;
    }

    if (!mounted) return;

    final shouldEnable = await showConciergeSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return ConciergeSheet(
          children: [
            const ConciergeSheetHeading(
              title: 'Know when your match is ready',
              intro: "We'll let you know as soon as we've picked a trainer for your request.",
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GSWButton(
                  size: GSWButtonSize.large,
                  variant: GSWButtonVariant.primary,
                  label: 'Allow notifications',
                  onPressed: () {
                    Navigator.of(sheetContext).pop(true);
                  },
                ),
                const SizedBox(height: 20),
                GSWButton(
                  size: GSWButtonSize.large,
                  variant: GSWButtonVariant.tertiary,
                  label: 'Not now',
                  onPressed: () {
                    Navigator.of(sheetContext).pop(false);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );

    if (shouldEnable != true) return;

    final settings = await pushService.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await pushService.registerCurrentDevice();
      }
    }
  }

  Widget _buildLanguages() {
    if (_availableLanguages.isEmpty) {
      return Text(
        'No language options available',
        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
      );
    }

    final languages = [..._availableLanguages];

    // English first, then keep the remaining values alphabetical.
    languages.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();

      if (aLower == 'english') return -1;
      if (bLower == 'english') return 1;

      return a.compareTo(b);
    });

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: languages.map((language) {
        final isSelected = _selectedLanguage == language;

        return _buildLanguageChip(
          label: language,
          selected: isSelected,
          onTap: () {
            setState(() {
              _selectedLanguage = isSelected ? null : language;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildLanguageChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GSWRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: selected ? GSWColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(GSWRadius.full),
            border: Border.all(
              width: 1,
              color: selected ? GSWColors.primary : GSWColors.surfaceInteractive,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARED CONTROLS
  // ---------------------------------------------------------------------------

  Widget _stepScrollView({required List<Widget> children}) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: children,
      ),
    );
  }

  Widget _fullWidthOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? GSWColors.primary : GSWColors.surfaceElevated,
      borderRadius: BorderRadius.circular(GSWRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(GSWRadius.full),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GSWRadius.full),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.borderSecondary),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelLarge.copyWith(
              color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FIXED BOTTOM ACTIONS
  // ---------------------------------------------------------------------------

  Widget _buildBottomActions() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: GSWColors.backgroundSecondary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(GSWRadius.card),
          topRight: Radius.circular(GSWRadius.card),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentStep > 1) ...[
                GSWButton(
                  size: GSWButtonSize.large,
                  variant: GSWButtonVariant.secondary,
                  label: 'Back',
                  onPressed: _goBack,
                ),

                const SizedBox(height: 8),
              ],

              GSWButton(
                size: GSWButtonSize.large,
                variant: _canContinue && !_isSubmitting
                    ? GSWButtonVariant.primary
                    : GSWButtonVariant.disabled,
                label: _currentStep == 4 && _isSubmitting
                    ? 'Sending...'
                    : _currentStep == 4
                    ? 'Continue to send request'
                    : 'Continue',
                onPressed: !_canContinue || _isSubmitting
                    ? null
                    : _currentStep == 4
                    ? _continueFromHelpMeChoose
                    : _goNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalDefinition {
  const _GoalDefinition({
    required this.label,
    this.specialtySlugs = const {},
    this.alwaysAvailable = false,
  });

  final String label;
  final Set<String> specialtySlugs;
  final bool alwaysAvailable;
}

class EdgeToEdgeRangeSliderTrackShape extends RoundedRectRangeSliderTrackShape {
  const EdgeToEdgeRangeSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;

    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;

    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
