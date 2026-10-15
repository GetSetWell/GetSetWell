import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/gsw_colors.dart';
import '../../../../core/theme/gsw_typography.dart';
import '../../../../core/utils/gsw_format.dart';
import '../../../../core/widgets/buttons/gsw_button.dart';
import '../../data/repositories/trainer_repository.dart';
import '../../domain/models/trainer.dart';
import 'trainer_sheet_frame.dart';

class TrainerFilters {
  const TrainerFilters({
    this.service,
    this.specialty,
    this.areas = const <String>{},
    this.femaleOnly = false,
    this.languages = const <String>{},
    this.sessionModes = const <String>{},
    this.minPrice,
    this.maxPrice,
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

  /// Price bounds chosen by the user. Both null means no price filter, so
  /// trainers without a rate (or outside any default range) still show.
  final double? minPrice;
  final double? maxPrice;

  bool get hasPriceFilter => minPrice != null || maxPrice != null;

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
        !hasPriceFilter;
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
    bool clearPrice = false,
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
      minPrice: clearPrice ? null : minPrice ?? this.minPrice,
      maxPrice: clearPrice ? null : maxPrice ?? this.maxPrice,
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

    if (hasPriceFilter) {
      final price = trainer.pricePerSession?.toDouble();

      if (price == null) {
        return false;
      }

      if (minPrice != null && price < minPrice!) {
        return false;
      }

      if (maxPrice != null && price > maxPrice!) {
        return false;
      }
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

      // GSWSheetDragDismiss owns the vertical drag, so the sheet closes when
      // dragged down anywhere (the list scrolls first, then the sheet moves).
      enableDrag: false,

      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: TrainerSheetFrame.scrim,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: TrainerSheetFrame.fullHeightFactor,
          alignment: Alignment.bottomCenter,
          child: GSWSheetDragDismiss(
            child: TrainerFiltersBottomSheet(trainers: trainers, initialFilters: initialFilters),
          ),
        );
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

  /// Slider bounds, derived from the live trainer rates
  /// (TrainerRepository.getAvailablePrices), falling back to the rates of the
  /// trainers passed in while that loads.
  double? _priceFloor;
  double? _priceCeiling;

  /// Current slider values. Only applied as a filter once the user has
  /// moved the slider ([_priceTouched]).
  double? _budgetMinValue;
  double? _budgetMaxValue;
  bool _priceTouched = false;

  bool get _hasPriceRange =>
      _priceFloor != null && _priceCeiling != null && _priceCeiling! > _priceFloor!;

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

    _setPriceBounds(
      widget.trainers
          .map((trainer) => trainer.pricePerSession)
          .whereType<double>()
          .toList(),
    );

    if (initial.hasPriceFilter) {
      _priceTouched = true;
      _budgetMinValue = initial.minPrice ?? _priceFloor;
      _budgetMaxValue = initial.maxPrice ?? _priceCeiling;
    }

    _loadRelationalFilterData();
    _loadPriceBounds();
  }

  void _setPriceBounds(List<num> prices) {
    if (prices.isEmpty) return;

    final sorted = prices.map((price) => price.toDouble()).toList()..sort();

    _priceFloor = sorted.first.floorToDouble();
    _priceCeiling = sorted.last.ceilToDouble();

    if (!_priceTouched) {
      _budgetMinValue = _priceFloor;
      _budgetMaxValue = _priceCeiling;
    } else {
      // Widen the range so a value chosen earlier is never clipped.
      if (_budgetMinValue != null && _budgetMinValue! < _priceFloor!) {
        _priceFloor = _budgetMinValue;
      }

      if (_budgetMaxValue != null && _budgetMaxValue! > _priceCeiling!) {
        _priceCeiling = _budgetMaxValue;
      }
    }
  }

  Future<void> _loadPriceBounds() async {
    try {
      final prices = await TrainerRepository(_supabase).getAvailablePrices();

      if (!mounted || prices.isEmpty) return;

      setState(() => _setPriceBounds(prices));
    } catch (error) {
      debugPrint('Trainer price bounds load failed: $error');
    }
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
      minPrice: _priceTouched ? _budgetMinValue : null,
      maxPrice: _priceTouched ? _budgetMaxValue : null,
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

      _priceTouched = false;
      _budgetMinValue = _priceFloor;
      _budgetMaxValue = _priceCeiling;
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

    final speciality = _selectedSpecialty ?? _selectedService;

    if (speciality != null) {
      parts.add(speciality);
    }

    if (_selectedArea != null) {
      parts.add(_selectedArea!);
    }

    if (_femaleOnly) {
      parts.add('female trainers');
    }

    if (_selectedLanguage != null) {
      parts.add(_selectedLanguage!);
    }

    if (_selectedSessionMode != null) {
      parts.add(_selectedSessionMode!.toLowerCase());
    }

    if (_priceTouched && _budgetMinValue != null && _budgetMaxValue != null) {
      parts.add(
        '${GSWMoney.aed(_budgetMinValue!.round())} to ${GSWMoney.amount(_budgetMaxValue!.round())}',
      );
    }

    if (parts.isEmpty) {
      return 'These filters leave nobody. Try removing one.';
    }

    if (parts.length == 1) {
      return '${parts.first} leaves nobody right now. Try a different choice.';
    }

    final combined = '${parts.join(' plus ')} leaves nobody.';

    if (_showAreaRecovery) {
      return '$combined The area is the tight one; the other filters are fine on their own.';
    }

    return '$combined Try removing one.';
  }

  // ---------------------------------------------------------------------------
  // UI
  // Figma 8.2 Filters / 8.3 No results: full-height sheet (790 of 844),
  // 28px grabber zone, 16px sides, title row 30, 24px between groups,
  // group label then 8px then 40px chips (8px gaps), sticky 92px bottom bar.
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: const BoxDecoration(
            color: GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const TrainerSheetGrabber(),

              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(overscroll: false, scrollbars: false),
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _buildHeader(),

                      const SizedBox(height: 24),

                      _buildGroup(
                        'Speciality',
                        [
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

                      const SizedBox(height: 24),

                      _buildGroup('Area', [
                        for (final area in _areas)
                          _buildChip(
                            label: area,
                            selected: _selectedArea == area,
                            onTap: () => _selectArea(area),
                          ),
                      ]),

                      const SizedBox(height: 24),

                      _buildGroup('Trainer', [
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
                      ]),

                      const SizedBox(height: 24),

                      _buildGroup('Session', [
                        for (final mode in _sessionModes)
                          _buildChip(
                            label: mode,
                            selected: _selectedSessionMode == mode,
                            onTap: () => _selectSessionMode(mode),
                          ),
                      ]),

                      if (_hasPriceRange) ...[
                        const SizedBox(height: 24),

                        _buildSectionLabel('Price per session'),

                        const SizedBox(height: 8),

                        Text(
                          '${GSWMoney.aed((_budgetMinValue ?? _priceFloor!).round())} '
                          'to ${GSWMoney.aed((_budgetMaxValue ?? _priceCeiling!).round())}',
                          style: GSWTextStyles.bodyLarge.copyWith(
                            color: GSWColors.textPrimary,
                            height: 20 / 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _buildPriceSlider(),
                      ],

                      if (_metadataLoadFailed) ...[
                        const SizedBox(height: 16),

                        Text(
                          'Some filters could not be loaded. You can still filter by speciality, area, trainer and price.',
                          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_showNoResultsExplainer) _buildNoResultsExplainer(),

              _buildBottomAction(),
            ],
          ),
        );
  }

  bool get _noMatches {
    final checking = _metadataLoading && _usesRelationalFilter;

    return !checking && _matches.isEmpty;
  }

  bool get _showNoResultsExplainer => _noMatches && !_currentFilters.isEmpty;

  Widget _buildHeader() {
    return SizedBox(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _noMatches ? 'No trainers match' : 'Filters',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: trainerSheetHeadingStyle(),
            ),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _clearAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                'Clear all',
                style: GSWTextStyles.labelMedium.copyWith(
                  color: GSWColors.textAccent,
                  height: 20 / 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String label, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(label),

        const SizedBox(height: 8),

        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
    );
  }

  Widget _buildChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GSWRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Figma 8.2: unselected chips have no fill, a Border/Disabled ring
          // and Text/Secondary labels; selected chips are solid lime.
          decoration: BoxDecoration(
            color: selected ? GSWColors.primary : null,
            borderRadius: BorderRadius.circular(GSWRadius.full),
            border: Border.all(color: selected ? GSWColors.primary : GSWColors.borderDisabled),
          ),
          // widthFactor 1 keeps the chip hugging its label inside the Wrap
          // (an aligned Container would stretch to the full row).
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: GSWTextStyles.labelMedium.copyWith(
                color: selected ? GSWColors.textInverse : GSWColors.textSecondary,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSlider() {
    final floor = _priceFloor!;
    final ceiling = _priceCeiling!;

    return SizedBox(
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
          min: floor,
          max: ceiling,
          values: RangeValues(
            (_budgetMinValue ?? floor).clamp(floor, ceiling),
            (_budgetMaxValue ?? ceiling).clamp(floor, ceiling),
          ),
          onChanged: (RangeValues values) {
            setState(() {
              _priceTouched = true;
              _budgetMinValue = values.start;
              _budgetMaxValue = values.end;
            });
          },
        ),
      ),
    );
  }

  /// 8.3: explains which filter combination leaves nobody. Figma: full
  /// sheet width, #2E3944 fill, 12px radius, 14/12 padding, Regular 13/19.
  Widget _buildNoResultsExplainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(GSWRadius.control),
      ),
      child: Text(
        _recoveryMessage,
        style: GSWTextStyles.bodyMedium.copyWith(
          color: GSWColors.textPrimary,
          fontSize: 13,
          height: 19 / 13,
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    final waitingForMetadata = _metadataLoading && _usesRelationalFilter;

    if (waitingForMetadata) {
      return const TrainerSheetBottomBar(
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

    if (_showAreaRecovery) {
      return TrainerSheetBottomBar(
        child: GSWButton(
          label: _recoveryButtonLabel,
          onPressed: _dropAreaAndApply,
          variant: GSWButtonVariant.primary,
          size: GSWButtonSize.large,
        ),
      );
    }

    if (count == 0) {
      return TrainerSheetBottomBar(
        child: GSWButton(
          label: 'Clear all filters',
          onPressed: _clearAll,
          variant: GSWButtonVariant.primary,
          size: GSWButtonSize.large,
        ),
      );
    }

    return TrainerSheetBottomBar(
      child: GSWButton(
        label: _buttonLabel,
        onPressed: _apply,
        variant: GSWButtonVariant.primary,
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
            borderRadius: BorderRadius.circular(GSWRadius.control),
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
