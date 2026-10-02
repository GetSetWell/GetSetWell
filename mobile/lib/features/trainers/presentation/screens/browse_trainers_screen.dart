import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/widgets/buttons/gsw_toggle.dart';
import 'package:mobile/core/widgets/common/header.dart';
import 'package:mobile/core/widgets/navigation/gsw_bottom_nav.dart';
import 'package:mobile/features/booking/data/services/active_concierge_match_service.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_card.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_filters_bottom_sheet.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_matching_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/gsw_icons.dart';
import '../../../../core/theme/gsw_sizes.dart';
import '../../../../core/widgets/badges/gsw_fillter_chip.dart';
import '../../../../core/widgets/common/gsw_status_pill.dart';
import '../../data/repositories/trainer_repository.dart';
import '../../domain/models/trainer.dart';

class _TrainerCategory {
  const _TrainerCategory({required this.label, this.iconPath, this.isComingSoon = false});

  final String label;
  final String? iconPath;
  final bool isComingSoon;
}

TrainerFilters _trainerFilters = const TrainerFilters();

class BrowseTrainersScreen extends StatefulWidget {
  const BrowseTrainersScreen({super.key});

  @override
  State<BrowseTrainersScreen> createState() => _BrowseTrainersScreenState();
}

class _BrowseTrainersScreenState extends State<BrowseTrainersScreen> {
  bool _showFemaleOnly = false;
  late final TrainerRepository _trainerRepository;
  late final ActiveConciergeMatchService _activeConciergeMatchService;

  late final Future<List<Trainer>> _trainersFuture;
  String _selectedCategory = 'All';

  final List<_TrainerCategory> _categories = [
    const _TrainerCategory(label: 'All'),
    const _TrainerCategory(label: 'Personal Training', iconPath: GSWIcons.dumbell),
    const _TrainerCategory(label: 'Yoga and Pilates', iconPath: GSWIcons.yoga),
    const _TrainerCategory(
      label: 'Nutrition Coaching',
      iconPath: GSWIcons.nutrition,
      isComingSoon: true,
    ),
    const _TrainerCategory(
      label: 'Recovery and Mobility',
      iconPath: GSWIcons.recovery,
      isComingSoon: true,
    ),
  ];
  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;

    _trainerRepository = TrainerRepository(Supabase.instance.client);
    _activeConciergeMatchService = ActiveConciergeMatchService(client);

    _trainersFuture = _trainerRepository.getTrainers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Header(),

                const SizedBox(height: 24),

                _buildHeadline(context),

                const SizedBox(height: 24),

                _buildLocationRow(context),

                const SizedBox(height: 24),

                _buildFemaleOnlyToggle(context),

                const SizedBox(height: 24),

                _buildCategoryFilters(context),

                const SizedBox(height: 16),

                Text(
                  "Prices are the trainer's rate. A 5% service fee is added when you book.",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary, height: 1.4),
                ),

                const SizedBox(height: 16),

                // Trainer cards...
                _buildTrainerList(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const GSWBottomNav(currentItem: GSWBottomNavItem.trainers),
    );
  }

  Widget _buildHeadline(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'FIND YOUR ', style: Theme.of(context).textTheme.displayLarge),
              TextSpan(
                text: 'TRAINER ',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: GSWColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'We check every trainer’s ID, qualifications and references, and meet them in person.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          GSWIcons.location,
          width: GSWSizes.icon,
          height: GSWSizes.icon,
          colorFilter: const ColorFilter.mode(Color(0xFFDAE64B), BlendMode.srcIn),
        ),

        const SizedBox(width: 8),

        Text(
          'Dubai',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.primary),
        ),

        const SizedBox(width: 8),

        Text(
          '·',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.textDisabled),
        ),

        const SizedBox(width: 8),

        Flexible(
          fit: FlexFit.loose,
          child: Text(
            'Abu Dhabi and Sharjah',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),

        const GSWStatusPill(label: 'Soon'),
      ],
    );
  }

  Widget _buildFemaleOnlyToggle(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 12),
      decoration: BoxDecoration(
        color: GSWColors.backgroundSecondary,
        border: Border.all(color: GSWColors.borderSecondary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Show female trainers only',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: GSWColors.textPrimary),
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

  Future<void> _openFilters() async {
    try {
      final trainers = await _trainersFuture;

      if (!mounted) return;

      final result = await TrainerFiltersBottomSheet.show(
        context,
        trainers: trainers,
        initialFilters: _trainerFilters.copyWith(
          service: _selectedCategory == 'All' ? null : _selectedCategory,
          clearService: _selectedCategory == 'All',
          femaleOnly: _showFemaleOnly,
        ),
      );

      if (result == null || !mounted) {
        return;
      }

      setState(() {
        _trainerFilters = result;

        _showFemaleOnly = result.femaleOnly;

        _selectedCategory = result.service ?? 'All';
      });
    } catch (error) {
      debugPrint('Could not open trainer filters: $error');
    }
  }

  Widget _buildCategoryFilters(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          InkWell(
            onTap: _openFilters,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: GSWColors.surfaceInteractive,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GSWColors.borderSecondary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    GSWIcons.filter,
                    width: 18,
                    height: 18,
                    colorFilter: const ColorFilter.mode(GSWColors.textPrimary, BlendMode.srcIn),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    _filterButtonLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: GSWColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          for (int index = 0; index < _categories.length; index++) ...[
            Builder(
              builder: (context) {
                final category = _categories[index];

                final isSelected = !category.isComingSoon && _selectedCategory == category.label;

                return GSWFilterChip(
                  label: category.label,
                  iconPath: category.iconPath,
                  isSelected: isSelected,
                  isEnabled: !category.isComingSoon,
                  trailing: category.isComingSoon ? const GSWStatusPill(label: 'Soon') : null,
                  onTap: () {
                    if (category.isComingSoon) {
                      return;
                    }

                    setState(() {
                      _selectedCategory = category.label;
                    });
                  },
                );
              },
            ),

            if (index != _categories.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String get _filterButtonLabel {
    final count = _appliedFilterCount;

    if (count == 0) {
      return 'Filters';
    }

    return 'Filters ($count)';
  }

  Widget _buildMatchingCardIfAllowed() {
    return FutureBuilder<bool>(
      future: _activeConciergeMatchService.hasActiveMatch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            snapshot.data == true) {
          return const SizedBox.shrink();
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Unable to load trainers right now.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
            ),
          );
        }

        final trainers = snapshot.data ?? [];

        final activeFilters = _trainerFilters.copyWith(
          service: _selectedCategory == 'All' ? null : _selectedCategory,
          clearService: _selectedCategory == 'All',
          femaleOnly: _showFemaleOnly,
        );

        final filteredTrainers = trainers.where(activeFilters.matchesTrainer).toList();

        if (filteredTrainers.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Center(
                child: Text(
                  'No trainers match these filters.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: GSWColors.textSecondary),
                ),
              ),

              const SizedBox(height: 20),

              _buildMatchingCardIfAllowed(),
            ],
          );
        }

        return Column(
          children: [
            for (int index = 0; index < filteredTrainers.length; index++) ...[
              Builder(
                builder: (context) {
                  final trainer = filteredTrainers[index];

                  return TrainerCard(
                    name: trainer.fullName,
                    service: trainer.primaryService ?? 'Personal Training',
                    location: trainer.serviceArea ?? 'Dubai',
                    price: trainer.pricePerSession ?? 0,
                    languages: trainer.languages,
                    imageUrl: trainer.profileImageUrl,
                    verificationChecks: trainer.verificationChecks,
                    onTap: () {
                      context.push(GSWRoutes.trainerProfile, extra: trainer);
                    },
                  );
                },
              ),
              if (index == 0) ...[const SizedBox(height: 24), _buildMatchingCardIfAllowed()],
              if (index != filteredTrainers.length - 1) const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }

  int get _appliedFilterCount {
    var count = 0;

    if (_trainerFilters.service != null) {
      count++;
    }

    if (_trainerFilters.specialty != null) {
      count++;
    }

    if (_trainerFilters.areas.isNotEmpty) {
      count++;
    }

    if (_trainerFilters.femaleOnly || _trainerFilters.languages.isNotEmpty) {
      count++;
    }

    if (_trainerFilters.sessionModes.isNotEmpty) {
      count++;
    }

    if (_trainerFilters.minPrice > 150 || _trainerFilters.maxPrice < 400) {
      count++;
    }

    return count;
  }
}
