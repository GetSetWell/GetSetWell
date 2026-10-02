import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../domain/models/trainer.dart';

class TrainerFilters {
  const TrainerFilters({
    this.service,
    this.specialty,
    this.areas = const <String>{},
    this.femaleOnly = false,
    this.languages = const <String>{},
    this.sessionModes = const <String>{},
    this.minPrice = 150,
    this.maxPrice = 400,
    this.resolvedTrainerIds = const <String>{},
    this.restrictToResolvedTrainerIds = false,
  });

  final String? service;

  /// Used for specialty filters that are stored in
  /// trainer_specialties rather than primaryService.
  final String? specialty;

  /// Kept as Sets for backwards compatibility with
  /// BrowseTrainersScreen.
  ///
  /// The UI in this sheet guarantees a maximum of one
  /// selected value per group.
  final Set<String> areas;
  final bool femaleOnly;
  final Set<String> languages;
  final Set<String> sessionModes;

  final double minPrice;
  final double maxPrice;

  /// Specialty and session-mode information currently lives outside the
  /// Trainer object used by BrowseTrainersScreen.
  ///
  /// The bottom sheet resolves those relations before returning the filter.
  /// This lets BrowseTrainersScreen continue calling matchesTrainer() without
  /// having to load those relations again.
  final Set<String> resolvedTrainerIds;
  final bool restrictToResolvedTrainerIds;

  bool get isEmpty {
    return service == null &&
        specialty == null &&
        areas.isEmpty &&
        !femaleOnly &&
        languages.isEmpty &&
        sessionModes.isEmpty &&
        minPrice <= 150 &&
        maxPrice >= 400;
  }

  TrainerFilters copyWith({
    String? service,
    bool clearService = false,
    String? specialty,
    bool clearSpecialty = false,
    Set<String>? areas,
    bool? femaleOnly,
    Set<String>? languages,
    Set<String>? sessionModes,
    double? minPrice,
    double? maxPrice,
    Set<String>? resolvedTrainerIds,
    bool? restrictToResolvedTrainerIds,
  }) {
    return TrainerFilters(
      service: clearService ? null : service ?? this.service,
      specialty: clearSpecialty ? null : specialty ?? this.specialty,
      areas: areas ?? this.areas,
      femaleOnly: femaleOnly ?? this.femaleOnly,
      languages: languages ?? this.languages,
      sessionModes: sessionModes ?? this.sessionModes,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      resolvedTrainerIds: resolvedTrainerIds ?? this.resolvedTrainerIds,
      restrictToResolvedTrainerIds:
          restrictToResolvedTrainerIds ?? this.restrictToResolvedTrainerIds,
    );
  }

  bool matchesTrainer(Trainer trainer, {bool ignoreArea = false}) {
    if (restrictToResolvedTrainerIds && !resolvedTrainerIds.contains(trainer.id)) {
      return false;
    }

    if (service != null) {
      final trainerService = trainer.primaryService?.trim().toLowerCase();

      final wantedService = service!.trim().toLowerCase();

      if (trainerService != wantedService) {
        return false;
      }
    }

    if (femaleOnly) {
      final gender = trainer.gender?.trim().toLowerCase() ?? '';

      if (gender != 'female') {
        return false;
      }
    }

    if (!ignoreArea && areas.isNotEmpty) {
      final trainerArea = trainer.serviceArea?.trim().toLowerCase() ?? '';

      final selectedArea = areas.first;

      if (!_matchesArea(trainerArea, selectedArea)) {
        return false;
      }
    }

    if (languages.isNotEmpty) {
      final selectedLanguage = languages.first.trim().toLowerCase();

      final trainerLanguages = trainer.languages
          .map((language) => language.trim().toLowerCase())
          .toSet();

      if (!trainerLanguages.contains(selectedLanguage)) {
        return false;
      }
    }

    final price = trainer.pricePerSession?.toDouble();

    if (price == null) {
      return false;
    }

    if (price < minPrice || price > maxPrice) {
      return false;
    }

    return true;
  }

  static bool _matchesArea(String trainerArea, String selectedArea) {
    final area = selectedArea.trim().toLowerCase();

    switch (area) {
      case 'marina and jlt':
        return trainerArea.contains('marina') || trainerArea.contains('jlt');

      case 'downtown':
        return trainerArea.contains('downtown') || trainerArea.contains('business bay');

      case 'arabian ranches':
        return trainerArea.contains('arabian ranches');

      case 'dubai hills':
        return trainerArea.contains('dubai hills');

      case 'silicon oasis':
        return trainerArea.contains('silicon oasis');

      default:
        return trainerArea.contains(area);
    }
  }
}

class TrainerFiltersBottomSheet extends StatefulWidget {
  const TrainerFiltersBottomSheet({
    super.key,
    required this.trainers,
    this.initialFilters = const TrainerFilters(),
  });

  final List<Trainer> trainers;
  final TrainerFilters initialFilters;

  static Future<TrainerFilters?> show(
    BuildContext context, {
    required List<Trainer> trainers,
    TrainerFilters initialFilters = const TrainerFilters(),
  }) {
    return showModalBottomSheet<TrainerFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,

      // IMPORTANT:
      // DraggableScrollableSheet below owns the vertical drag gesture.
      // Leaving the modal route draggable as well creates two competing
      // drag recognizers and causes the lag you were seeing.
      enableDrag: false,

      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetContext) {
        return TrainerFiltersBottomSheet(trainers: trainers, initialFilters: initialFilters);
      },
    );
  }

  @override
  State<TrainerFiltersBottomSheet> createState() => _TrainerFiltersBottomSheetState();
}

class _TrainerFiltersBottomSheetState extends State<TrainerFiltersBottomSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // AVAILABLE OPTIONS
  // ---------------------------------------------------------------------------

  static const _areas = [
    'Marina and JLT',
    'Downtown',
    'Arabian Ranches',
    'Dubai Hills',
    'Silicon Oasis',
  ];

  static const _languages = ['English', 'Arabic', 'Hindi'];

  static const _sessionModes = ['Comes to me', 'At their gym', 'Outdoors'];

  // ---------------------------------------------------------------------------
  // PRICE RANGE
  // ---------------------------------------------------------------------------

  static const double absoluteMin = 150;
  static const double absoluteMax = 400;

  double? _budgetMinValue;
  double? _budgetMaxValue;

  // ---------------------------------------------------------------------------
  // SINGLE-SELECTION STATE
  // ---------------------------------------------------------------------------

  String? _selectedService;
  String? _selectedSpecialty;
  String? _selectedArea;

  /// Trainer section is intentionally mutually exclusive.
  ///
  /// Either female-only OR one language can be active.
  bool _femaleOnly = false;
  String? _selectedLanguage;

  String? _selectedSessionMode;

  // ---------------------------------------------------------------------------
  // RELATIONAL FILTER DATA
  // ---------------------------------------------------------------------------

  bool _metadataLoading = true;
  bool _metadataLoadFailed = false;

  /// trainer id -> specialty slugs
  final Map<String, Set<String>> _trainerSpecialties = {};

  /// trainer id -> training-location slugs
  final Map<String, Set<String>> _trainerLocations = {};

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    final initial = widget.initialFilters;

    _selectedService = initial.service;

    _selectedSpecialty = initial.specialty;

    _selectedArea = initial.areas.isNotEmpty ? initial.areas.first : null;

    _femaleOnly = initial.femaleOnly;

    _selectedLanguage = initial.languages.isNotEmpty ? initial.languages.first : null;

    _selectedSessionMode = initial.sessionModes.isNotEmpty ? initial.sessionModes.first : null;

    _budgetMinValue = initial.minPrice.clamp(absoluteMin, absoluteMax);

    _budgetMaxValue = initial.maxPrice.clamp(absoluteMin, absoluteMax);

    _loadRelationalFilterData();
  }

  Future<void> _loadRelationalFilterData() async {
    try {
      final results = await Future.wait([
        _supabase.from('trainer_specialties').select('''
              trainer_id,
              specialties (
                slug
              )
              '''),

        _supabase.from('trainer_training_locations').select('''
              trainer_id,
              training_locations (
                slug,
                location_type
              )
              '''),
      ]);

      final specialtyRows = results[0];

      final locationRows = results[1];

      for (final rawRow in specialtyRows) {
        final row = Map<String, dynamic>.from(rawRow);

        final trainerId = row['trainer_id']?.toString();

        if (trainerId == null) {
          continue;
        }

        final specialty = row['specialties'];

        if (specialty is Map) {
          final slug = specialty['slug']?.toString().trim().toLowerCase();

          if (slug != null && slug.isNotEmpty) {
            _trainerSpecialties.putIfAbsent(trainerId, () => <String>{}).add(slug);
          }
        }
      }

      for (final rawRow in locationRows) {
        final row = Map<String, dynamic>.from(rawRow);

        final trainerId = row['trainer_id']?.toString();

        if (trainerId == null) {
          continue;
        }

        final location = row['training_locations'];

        if (location is Map) {
          final slug = location['slug']?.toString().trim().toLowerCase();

          if (slug != null && slug.isNotEmpty) {
            _trainerLocations.putIfAbsent(trainerId, () => <String>{}).add(slug);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _metadataLoading = false;
        _metadataLoadFailed = false;
      });
    } catch (error) {
      debugPrint('Trainer filter metadata load failed: $error');

      if (!mounted) return;

      setState(() {
        _metadataLoading = false;
        _metadataLoadFailed = true;

        // Do not leave an advanced selection active if
        // the data needed to evaluate it could not load.
        _selectedSpecialty = null;
        _selectedSessionMode = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // FILTER BUILDING
  // ---------------------------------------------------------------------------

  bool get _usesRelationalFilter {
    return _selectedSpecialty != null || _selectedSessionMode != null;
  }

  Set<String> get _relationallyMatchingTrainerIds {
    if (!_usesRelationalFilter) {
      return const <String>{};
    }

    final matches = <String>{};

    for (final trainer in widget.trainers) {
      if (_matchesRelationalFilters(trainer)) {
        matches.add(trainer.id);
      }
    }

    return matches;
  }

  TrainerFilters get _currentFilters {
    final relationalIds = _relationallyMatchingTrainerIds;

    return TrainerFilters(
      service: _selectedService,
      specialty: _selectedSpecialty,
      areas: _selectedArea == null ? const <String>{} : {_selectedArea!},
      femaleOnly: _femaleOnly,
      languages: _selectedLanguage == null ? const <String>{} : {_selectedLanguage!},
      sessionModes: _selectedSessionMode == null ? const <String>{} : {_selectedSessionMode!},
      minPrice: _budgetMinValue ?? absoluteMin,
      maxPrice: _budgetMaxValue ?? absoluteMax,
      resolvedTrainerIds: relationalIds,
      restrictToResolvedTrainerIds: _usesRelationalFilter,
    );
  }

  bool _matchesRelationalFilters(Trainer trainer) {
    if (_selectedSpecialty != null) {
      final trainerSpecialties = _trainerSpecialties[trainer.id] ?? const <String>{};

      final acceptedSlugs = _specialtySlugsFor(_selectedSpecialty!);

      if (!trainerSpecialties.any(acceptedSlugs.contains)) {
        return false;
      }
    }

    if (_selectedSessionMode != null) {
      final trainerLocations = _trainerLocations[trainer.id] ?? const <String>{};

      final requiredSlug = _locationSlugFor(_selectedSessionMode!);

      if (requiredSlug == null || !trainerLocations.contains(requiredSlug)) {
        return false;
      }
    }

    return true;
  }

  Set<String> _specialtySlugsFor(String specialty) {
    switch (specialty) {
      case 'Strength':
        return const {'strength', 'strength-training', 'core-strength', 'muscle-building'};

      case 'Pre and postnatal':
        return const {'pre-postnatal', 'post-natal', 'postnatal', 'prenatal', 'womens-health'};

      case 'Mobility':
        return const {'mobility'};

      default:
        return const <String>{};
    }
  }

  String? _locationSlugFor(String mode) {
    switch (mode) {
      case 'Comes to me':
        return 'home';

      case 'At their gym':
        return 'gym';

      case 'Outdoors':
        return 'outdoors';

      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // RESULTS
  // ---------------------------------------------------------------------------

  List<Trainer> get _matches {
    if (_usesRelationalFilter && _metadataLoading) {
      return const <Trainer>[];
    }

    return widget.trainers.where(_currentFilters.matchesTrainer).toList();
  }

  List<Trainer> get _matchesWithoutArea {
    if (_usesRelationalFilter && _metadataLoading) {
      return const <Trainer>[];
    }

    return widget.trainers
        .where((trainer) => _currentFilters.matchesTrainer(trainer, ignoreArea: true))
        .toList();
  }

  bool get _showAreaRecovery {
    return !_metadataLoading &&
        _matches.isEmpty &&
        _selectedArea != null &&
        _matchesWithoutArea.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // SINGLE SELECT ACTIONS
  // ---------------------------------------------------------------------------

  void _selectService(String service) {
    setState(() {
      if (_selectedService == service) {
        _selectedService = null;
      } else {
        _selectedService = service;
      }

      // Only one option from Speciality can be active.
      _selectedSpecialty = null;
    });
  }

  void _selectSpecialty(String specialty) {
    if (_metadataLoadFailed) {
      _showMessage('Could not load specialty filters. Please try again.');

      return;
    }

    setState(() {
      if (_selectedSpecialty == specialty) {
        _selectedSpecialty = null;
      } else {
        _selectedSpecialty = specialty;
      }

      // Only one option from Speciality can be active.
      _selectedService = null;
    });
  }

  void _selectArea(String area) {
    setState(() {
      _selectedArea = _selectedArea == area ? null : area;
    });
  }

  void _selectFemaleOnly() {
    setState(() {
      if (_femaleOnly) {
        _femaleOnly = false;
      } else {
        _femaleOnly = true;

        // Trainer group is single-select.
        _selectedLanguage = null;
      }
    });
  }

  void _selectLanguage(String language) {
    setState(() {
      if (_selectedLanguage == language) {
        _selectedLanguage = null;
      } else {
        _selectedLanguage = language;

        // Trainer group is single-select.
        _femaleOnly = false;
      }
    });
  }

  void _selectSessionMode(String mode) {
    if (_metadataLoadFailed) {
      _showMessage('Could not load session filters. Please try again.');

      return;
    }

    setState(() {
      _selectedSessionMode = _selectedSessionMode == mode ? null : mode;
    });
  }

  void _clearAll() {
    setState(() {
      _selectedService = null;
      _selectedSpecialty = null;

      _selectedArea = null;

      _femaleOnly = false;
      _selectedLanguage = null;

      _selectedSessionMode = null;

      _budgetMinValue = absoluteMin;

      _budgetMaxValue = absoluteMax;
    });
  }

  // ---------------------------------------------------------------------------
  // APPLY
  // ---------------------------------------------------------------------------

  void _apply() {
    if (_metadataLoading && _usesRelationalFilter) {
      return;
    }

    Navigator.of(context).pop(_currentFilters);
  }

  void _dropAreaAndApply() {
    setState(() {
      _selectedArea = null;
    });

    final relaxedFilters = _currentFilters.copyWith(areas: const <String>{});

    Navigator.of(context).pop(relaxedFilters);
  }

  String get _buttonLabel {
    final count = _matches.length;

    return 'Show $count '
        '${count == 1 ? 'trainer' : 'trainers'}';
  }

  String get _recoveryButtonLabel {
    final count = _matchesWithoutArea.length;

    return 'Drop the area filter and show $count';
  }

  String get _recoveryMessage {
    final parts = <String>[];

    if (_selectedArea != null) {
      parts.add(_selectedArea!);
    }

    if (_femaleOnly) {
      parts.add('female trainers');
    }

    if (_selectedLanguage != null) {
      parts.add(_selectedLanguage!);
    }

    final minimum = (_budgetMinValue ?? absoluteMin).round();

    final maximum = (_budgetMaxValue ?? absoluteMax).round();

    if (minimum > absoluteMin || maximum < absoluteMax) {
      parts.add('AED $minimum to $maximum');
    }

    if (parts.isEmpty) {
      return 'These filters leave no trainers. Try removing one filter.';
    }

    return '${parts.join(' plus ')} leaves nobody. '
        'The area is the tight one; the other filters are fine on their own.';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    /*
     * IMPORTANT
     *
     * Only DraggableScrollableSheet owns vertical dragging.
     *
     * showModalBottomSheet(enableDrag: false) prevents Flutter's modal
     * BottomSheet gesture detector from competing with this one.
     *
     * The ListView MUST use the supplied scrollController. This gives
     * DraggableScrollableSheet one continuous gesture:
     *
     *   content scrolls
     *       ↓
     *   reaches the top
     *       ↓
     *   continued downward drag shrinks the sheet
     *       ↓
     *   reaching min extent dismisses the modal
     */
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      snap: false,
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHandle(),

                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(overscroll: false, scrollbars: false),
                    child: ListView(
                      controller: scrollController,

                      // No bouncing / stretching effect.
                      physics: const ClampingScrollPhysics(),

                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      children: [
                        _buildHeader(),

                        const SizedBox(height: 28),

                        // ---------------------------------------------------
                        // SPECIALITY
                        // ---------------------------------------------------
                        _buildSectionLabel('Speciality'),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(
                              label: 'Personal training',
                              selected: _selectedService == 'Personal Training',
                              onTap: () => _selectService('Personal Training'),
                            ),

                            _buildChip(
                              label: 'Yoga',
                              selected: _selectedService == 'Yoga and Pilates',
                              onTap: () => _selectService('Yoga and Pilates'),
                            ),

                            _buildChip(
                              label: 'Strength',
                              selected: _selectedSpecialty == 'Strength',
                              onTap: () => _selectSpecialty('Strength'),
                            ),

                            _buildChip(
                              label: 'Pre and postnatal',
                              selected: _selectedSpecialty == 'Pre and postnatal',
                              onTap: () => _selectSpecialty('Pre and postnatal'),
                            ),

                            _buildChip(
                              label: 'Mobility',
                              selected: _selectedSpecialty == 'Mobility',
                              onTap: () => _selectSpecialty('Mobility'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ---------------------------------------------------
                        // AREA
                        // ---------------------------------------------------
                        _buildSectionLabel('Area'),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final area in _areas)
                              _buildChip(
                                label: area,
                                selected: _selectedArea == area,
                                onTap: () => _selectArea(area),
                              ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ---------------------------------------------------
                        // TRAINER
                        // ---------------------------------------------------
                        _buildSectionLabel('Trainer'),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(
                              label: 'Female trainers only',
                              selected: _femaleOnly,
                              onTap: _selectFemaleOnly,
                            ),

                            for (final language in _languages)
                              _buildChip(
                                label: language,
                                selected: _selectedLanguage == language,
                                onTap: () => _selectLanguage(language),
                              ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ---------------------------------------------------
                        // SESSION
                        // ---------------------------------------------------
                        _buildSectionLabel('Session'),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final mode in _sessionModes)
                              _buildChip(
                                label: mode,
                                selected: _selectedSessionMode == mode,
                                onTap: () => _selectSessionMode(mode),
                              ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ---------------------------------------------------
                        // PRICE
                        // ---------------------------------------------------
                        _buildSectionLabel('Price per session'),

                        const SizedBox(height: 8),

                        Text(
                          'AED ${(_budgetMinValue ?? absoluteMin).round()} '
                          'to AED ${(_budgetMaxValue ?? absoluteMax).round()}',
                          style: GSWTextStyles.titleExtraSmall.copyWith(
                            color: GSWColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 2),

                        _buildPriceSlider(),

                        if (_metadataLoadFailed) ...[
                          const SizedBox(height: 14),

                          Text(
                            'Some filters could not be loaded. You can still use speciality type, area, trainer and price filters.',
                            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                          ),
                        ],

                        if (_showAreaRecovery) ...[
                          const SizedBox(height: 18),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: GSWColors.surfaceInteractive,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _recoveryMessage,
                              style: GSWTextStyles.bodyMedium.copyWith(
                                color: GSWColors.textPrimary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],

                        // Extra spacing so the last content never
                        // sits behind the sticky action.
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                _buildBottomAction(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      /*
       * The actual drag gesture is handled by
       * DraggableScrollableSheet.
       *
       * This larger hit region simply makes the top
       * of the sheet comfortable to grab.
       */
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: GSWColors.borderSecondary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final checking = _metadataLoading && _usesRelationalFilter;

    final noMatches = !checking && _matches.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            noMatches ? 'No trainers match' : 'Filters',
            style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
          ),
        ),

        TextButton(
          onPressed: _clearAll,
          style: TextButton.styleFrom(
            foregroundColor: GSWColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 40),
          ),
          child: Text(
            'Clear all',
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textSecondary));
  }

  Widget _buildChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? GSWColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.borderSecondary),
          ),
          child: Text(
            label,
            style: GSWTextStyles.labelLarge.copyWith(
              color: selected ? GSWColors.backgroundPrimary : GSWColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXACT CONTINUOUS RANGE SLIDER
  // ---------------------------------------------------------------------------

  Widget _buildPriceSlider() {
    return SizedBox(
      height: 32,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,

          activeTrackColor: GSWColors.primary,

          inactiveTrackColor: const Color(0xFF2E3944),

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

          // No divisions.
          // Continuous and smooth.
          values: RangeValues(
            (_budgetMinValue ?? absoluteMin).clamp(absoluteMin, absoluteMax),
            (_budgetMaxValue ?? absoluteMax).clamp(absoluteMin, absoluteMax),
          ),

          onChanged: (RangeValues values) {
            setState(() {
              _budgetMinValue = values.start;

              _budgetMaxValue = values.end;
            });
          },
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    final waitingForMetadata = _metadataLoading && _usesRelationalFilter;

    if (waitingForMetadata) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        color: GSWColors.backgroundPrimary,
        child: GSWButton(
          label: 'Checking trainers',
          onPressed: null,
          variant: GSWButtonVariant.disabled,
          size: GSWButtonSize.large,
          isLoading: true,
        ),
      );
    }

    final count = _matches.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(color: GSWColors.backgroundPrimary),
      child: _showAreaRecovery
          ? GSWButton(
              label: _recoveryButtonLabel,
              onPressed: _dropAreaAndApply,
              variant: GSWButtonVariant.primary,
              size: GSWButtonSize.large,
            )
          : GSWButton(
              label: _buttonLabel,
              onPressed: count > 0 ? _apply : null,
              variant: count > 0 ? GSWButtonVariant.primary : GSWButtonVariant.disabled,
              size: GSWButtonSize.large,
            ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          backgroundColor: GSWColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: GSWColors.borderSecondary),
          ),
        ),
      );
  }
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
