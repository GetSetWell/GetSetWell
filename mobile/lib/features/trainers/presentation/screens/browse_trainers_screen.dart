import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/core/widgets/buttons/gsw_toggle.dart';
import 'package:mobile/core/widgets/common/gsw_dashed_border.dart';
import 'package:mobile/core/widgets/common/header.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:mobile/features/booking/data/services/active_concierge_match_service.dart';
import 'package:mobile/features/booking/domain/models/active_concierge_match.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_card.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_filters_bottom_sheet.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_matching_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/gsw_icons.dart';
import '../../../../core/theme/gsw_radius.dart';
import '../../../../core/theme/gsw_sizes.dart';
import '../../../../core/widgets/common/gsw_status_pill.dart';
import '../../data/repositories/trainer_repository.dart';
import '../../domain/models/trainer.dart';

class _TrainerCategory {
  const _TrainerCategory({required this.label, this.iconPath, this.isComingSoon = false});

  final String label;
  final String? iconPath;
  final bool isComingSoon;
}

/// Figma 8.1 Trainers list (818:3362), with the 8.2 Filters / 8.3 No results
/// sheet opened from the Filters button.
class BrowseTrainersScreen extends StatefulWidget {
  const BrowseTrainersScreen({super.key});

  @override
  State<BrowseTrainersScreen> createState() => _BrowseTrainersScreenState();
}

class _BrowseTrainersScreenState extends State<BrowseTrainersScreen> {
  static const String _allCategory = 'All';

  /// Live categories: All, Personal Training, Yoga and Pilates.
  /// Nutrition Coaching and Recovery and Mobility are coming soon.
  static const List<_TrainerCategory> _categories = [
    _TrainerCategory(label: _allCategory),
    _TrainerCategory(label: 'Personal Training', iconPath: GSWIcons.dumbell),
    _TrainerCategory(label: 'Yoga and Pilates', iconPath: GSWIcons.yoga),
    _TrainerCategory(label: 'Nutrition Coaching', iconPath: GSWIcons.nutrition, isComingSoon: true),
    _TrainerCategory(label: 'Recovery and Mobility', iconPath: GSWIcons.recovery, isComingSoon: true),
  ];

  late final TrainerRepository _trainerRepository;
  late final ActiveConciergeMatchService _activeConciergeMatchService;

  late Future<List<Trainer>> _trainersFuture;

  /// Cached once per screen so the Help me choose card does not refetch and
  /// flicker on every rebuild.
  late Future<ActiveConciergeMatch?> _activeMatchFuture;

  /// Filter state lives in the screen, so it resets with the screen (and on
  /// logout) instead of leaking through a global.
  TrainerFilters _trainerFilters = const TrainerFilters();
  bool _showFemaleOnly = false;
  String _selectedCategory = _allCategory;

  @override
  void initState() {
    super.initState();

    final client = Supabase.instance.client;

    _trainerRepository = TrainerRepository(client);
    _activeConciergeMatchService = ActiveConciergeMatchService(client);

    _trainersFuture = _trainerRepository.getTrainers();
    _activeMatchFuture = _loadActiveMatch();
  }

  Future<ActiveConciergeMatch?> _loadActiveMatch() async {
    try {
      return await _activeConciergeMatchService.getCurrent();
    } catch (error) {
      debugPrint('Browse active match check failed: $error');
      rethrow;
    }
  }

  void _retryTrainers() {
    setState(() {
      _trainersFuture = _trainerRepository.getTrainers();
    });
  }

  TrainerFilters get _activeFilters {
    return _trainerFilters.copyWith(
      service: _selectedCategory == _allCategory ? null : _selectedCategory,
      clearService: _selectedCategory == _allCategory,
      femaleOnly: _showFemaleOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30, child: Header(showNotifications: false)),

                const SizedBox(height: 16),

                _buildHeadline(),

                const SizedBox(height: 16),

                _buildLocationRow(),

                const SizedBox(height: 16),

                _buildFemaleOnlyToggle(),

                const SizedBox(height: 16),

                _buildFilterRow(),

                _buildActiveFiltersBar(),

                const SizedBox(height: 16),

                Text(
                  "Prices are the trainer's rate. A 5% service fee is added when you book.",
                  style: GSWTextStyles.bodySmall.copyWith(
                    color: GSWColors.textSecondary,
                    height: 16 / 12,
                  ),
                ),

                const SizedBox(height: 16),

                _buildTrainerList(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.trainers),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FIND YOUR TRAINER',
          style: GSWTextStyles.displayLarge.copyWith(
            fontSize: 40,
            height: 44 / 40,
            color: GSWColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "We check every trainer's ID, qualifications and references before they appear here.",
          style: GSWTextStyles.bodyMedium.copyWith(
            color: GSWColors.textSecondary,
            height: 20 / 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          SvgPicture.asset(
            GSWIcons.location,
            width: GSWSizes.icon,
            height: GSWSizes.icon,
            colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
          ),

          const SizedBox(width: 8),

          Text(
            'Dubai',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textAccent, height: 20 / 14),
          ),

        ],
      ),
    );
  }

  Widget _buildFemaleOnlyToggle() {
    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.only(left: 12, right: 12),
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
              style: GSWTextStyles.bodySmall.copyWith(
                color: GSWColors.textPrimary,
                height: 16 / 12,
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            height: 26,
            child: GSWToggle(
              value: _showFemaleOnly,
              onChanged: (value) {
                setState(() {
                  _showFemaleOnly = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Future<void> _openFilters() async {
    try {
      final trainers = await _trainersFuture;

      if (!mounted) return;

      final result = await TrainerFiltersBottomSheet.show(
        context,
        trainers: trainers,
        initialFilters: _activeFilters,
      );

      if (result == null || !mounted) {
        return;
      }

      setState(() {
        _trainerFilters = result;
        _showFemaleOnly = result.femaleOnly;

        final service = result.service;
        final isLiveCategory = _categories.any(
          (category) => !category.isComingSoon && category.label == service,
        );

        _selectedCategory = isLiveCategory ? service! : _allCategory;
      });
    } catch (error) {
      debugPrint('Could not open trainer filters: $error');
    }
  }

  void _clearFilters() {
    setState(() {
      _trainerFilters = const TrainerFilters();
      _showFemaleOnly = false;
      _selectedCategory = _allCategory;
    });
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          _FiltersButton(label: _filterButtonLabel, onTap: _openFilters),

          const SizedBox(width: 8),

          Container(width: 1, height: 24, color: GSWColors.borderDisabled),

          const SizedBox(width: 8),

          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];

                return _CategoryChip(
                  label: category.label,
                  iconPath: category.iconPath,
                  isComingSoon: category.isComingSoon,
                  isSelected: !category.isComingSoon && _selectedCategory == category.label,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category.label;

                      // Speciality is single-select: a category replaces any
                      // speciality picked in the sheet. The resolved trainer
                      // ids were computed with that speciality, so they are
                      // dropped too (with the session filter that shared them).
                      if (_trainerFilters.specialty != null) {
                        _trainerFilters = _trainerFilters.copyWith(
                          clearSpecialty: true,
                          sessionModes: const <String>{},
                          resolvedTrainerIds: const <String>{},
                          restrictToResolvedTrainerIds: false,
                        );
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Shown only while a filter is on, right under the filter row where the
  /// eye already is (Fitts's law, proximity). The result count makes the
  /// filter's effect visible, and "Clear all" is the one obvious way back to
  /// every trainer (Jakob's law: the pattern people know from shopping apps).
  Widget _buildActiveFiltersBar() {
    final count = _appliedFilterCount;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FutureBuilder<List<Trainer>>(
                future: _trainersFuture,
                builder: (context, snapshot) {
                  final trainers = snapshot.data;
                  final shown = trainers?.where(_activeFilters.matchesTrainer).length;

                  final summary = shown == null
                      ? (count == 1 ? '1 filter on' : '$count filters on')
                      : 'Showing $shown of ${trainers!.length} ${trainers.length == 1 ? 'trainer' : 'trainers'}';

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary,
                          style: GSWTextStyles.bodySmall.copyWith(
                            color: GSWColors.textSecondary,
                            height: 16 / 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ClearFiltersButton(onTap: _clearFilters),
                    ],
                  );
                },
              ),
            ),
    );
  }

  int get _appliedFilterCount {
    final filters = _activeFilters;
    var count = 0;

    if (filters.service != null || filters.specialty != null) count++;
    if (filters.areas.isNotEmpty) count++;
    if (filters.femaleOnly || filters.languages.isNotEmpty) count++;
    if (filters.sessionModes.isNotEmpty) count++;
    if (filters.hasPriceFilter) count++;

    return count;
  }

  String get _filterButtonLabel {
    final count = _appliedFilterCount;

    return count == 0 ? 'Filters' : 'Filters ($count)';
  }

  // ---------------------------------------------------------------------------
  // LIST
  // ---------------------------------------------------------------------------

  Widget _buildMatchingCard() {
    return FutureBuilder<ActiveConciergeMatch?>(
      future: _activeMatchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError) {
          // If we cannot confirm whether a request is open, keep the entry
          // point hidden rather than risk a second request.
          return const SizedBox.shrink();
        }

        final activeMatch = snapshot.data;

        if (activeMatch != null) {
          return TrainerMatchingCard.requestOpen(
            onTap: () {
              context.push(
                activeMatch.isMatched ? GSWRoutes.yourMatch : GSWRoutes.conciergeRequestStatus,
                extra: activeMatch.id,
              );
            },
          );
        }

        return TrainerMatchingCard(
          onTap: () {
            context.push(GSWRoutes.helpMeChoose);
          },
        );
      },
    );
  }

  Widget _buildTrainerList() {
    return FutureBuilder<List<Trainer>>(
      future: _trainersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: GSWColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Trainers load failed: ${snapshot.error}');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We could not load trainers. Check your connection and try again.',
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),

              const SizedBox(height: 16),

              GSWButton(
                label: 'Try again',
                variant: GSWButtonVariant.secondary,
                size: GSWButtonSize.medium,
                onPressed: _retryTrainers,
              ),
            ],
          );
        }

        final trainers = snapshot.data ?? const <Trainer>[];
        final filteredTrainers = trainers.where(_activeFilters.matchesTrainer).toList();

        if (filteredTrainers.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trainers.isEmpty ? 'No trainers yet' : 'No trainers match',
                style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
              ),

              const SizedBox(height: 8),

              Text(
                trainers.isEmpty
                    ? 'New trainers are being checked. Tell us what you need and we will help you find someone.'
                    : 'Try removing a filter, or tell us what you need and a real person will help.',
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: GSWColors.textSecondary,
                  height: 20 / 14,
                ),
              ),

              if (trainers.isNotEmpty) ...[
                const SizedBox(height: 16),

                GSWButton(
                  label: 'Clear filters',
                  variant: GSWButtonVariant.secondary,
                  size: GSWButtonSize.medium,
                  onPressed: _clearFilters,
                ),
              ],

              const SizedBox(height: 16),

              _buildMatchingCard(),
            ],
          );
        }

        return Column(
          children: [
            for (int index = 0; index < filteredTrainers.length; index++) ...[
              _buildTrainerCard(filteredTrainers[index]),

              // Help me choose sits after the first card (8.1).
              if (index == 0) ...[const SizedBox(height: 16), _buildMatchingCard()],

              if (index != filteredTrainers.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTrainerCard(Trainer trainer) {
    return TrainerCard(
      name: trainer.fullName,
      service: trainer.primaryService ?? '',
      location: trainer.serviceArea?.trim().isNotEmpty == true ? trainer.serviceArea! : 'Dubai',
      price: trainer.pricePerSession,
      languages: trainer.languages,
      imageUrl: trainer.profileImageUrl,
      verificationChecks: trainer.verificationChecks,
      onTap: () {
        context.push(GSWRoutes.trainerProfile, extra: trainer);
      },
    );
  }
}

/// Figma "Filters button": 36px tall, 14px sides, 16px filter icon, 8px gap,
/// label Medium 14 white on Surface/Interactive.
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GSWRadius.full),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: GSWColors.surfaceInteractive,
            borderRadius: BorderRadius.circular(GSWRadius.full),
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                GSWIcons.filter,
                width: GSWSizes.icon,
                height: GSWSizes.icon,
                colorFilter: const ColorFilter.mode(GSWColors.iconPrimary, BlendMode.srcIn),
              ),

              const SizedBox(width: 8),

              Text(
                label,
                style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category chip from 8.1: 36px tall, min width 72, 18px sides, optional 16px
/// icon and a "Soon" pill. Coming-soon chips use a dashed border and do nothing.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.isComingSoon,
    required this.onTap,
    this.iconPath,
  });

  final String label;
  final String? iconPath;
  final bool isSelected;
  final bool isComingSoon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = isSelected
        ? GSWColors.textInverse
        : isComingSoon
        ? GSWColors.textTertiary
        : GSWColors.textPrimary;

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 36,
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isSelected ? GSWColors.primary : GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(GSWRadius.full),
        border: isComingSoon
            ? null
            : Border.all(color: isSelected ? GSWColors.primary : GSWColors.borderSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconPath != null) ...[
            SvgPicture.asset(
              iconPath!,
              width: GSWSizes.icon,
              height: GSWSizes.icon,
              colorFilter: ColorFilter.mode(contentColor, BlendMode.srcIn),
            ),

            const SizedBox(width: 8),
          ],

          Text(
            label,
            style: GSWTextStyles.labelMedium.copyWith(color: contentColor, height: 1),
          ),

          if (isComingSoon) ...[const SizedBox(width: 8), const GSWStatusPill(label: 'Soon')],
        ],
      ),
    );

    if (isComingSoon) {
      return Semantics(
        enabled: false,
        label: '$label, coming soon',
        child: GSWDashedBorder(
          color: GSWColors.borderSecondary,
          radius: GSWRadius.full,
          strokeWidth: 1,
          dashWidth: 4,
          dashGap: 4,
          child: chip,
        ),
      );
    }

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: chip);
  }
}

/// "Clear all" pill: 36 tall with a 44 tall tap area, accent text and a
/// small close icon so it reads as "remove", not "apply".
class _ClearFiltersButton extends StatelessWidget {
  const _ClearFiltersButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear all filters',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GSWRadius.full),
              border: Border.all(color: GSWColors.primary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  GSWIcons.close,
                  width: 10,
                  height: 10,
                  colorFilter: const ColorFilter.mode(GSWColors.textAccent, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                Text(
                  'Clear all',
                  style: GSWTextStyles.labelMedium.copyWith(
                    color: GSWColors.textAccent,
                    height: 16 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
