import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/widgets/buttons/gsw_toggle.dart';
import 'package:mobile/core/widgets/common/header.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_card.dart';
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

class BrowseTrainersScreen extends StatefulWidget {
  const BrowseTrainersScreen({super.key});

  @override
  State<BrowseTrainersScreen> createState() => _BrowseTrainersScreenState();
}

class _BrowseTrainersScreenState extends State<BrowseTrainersScreen> {
  bool _showFemaleOnly = false;
  late final TrainerRepository _trainerRepository;
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

    _trainerRepository = TrainerRepository(Supabase.instance.client);

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

                const SizedBox(height: 24),

                // Trainer cards...
                _buildTrainerList(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildCategoryFilters(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];

          final isSelected = !category.isComingSoon && _selectedCategory == category.label;

          return GSWFilterChip(
            label: category.label,
            iconPath: category.iconPath,
            isSelected: isSelected,
            isEnabled: !category.isComingSoon,
            trailing: category.isComingSoon ? const GSWStatusPill(label: 'Soon') : null,
            onTap: () {
              setState(() {
                _selectedCategory = category.label;
              });
            },
          );
        },
      ),
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

        final filteredTrainers = trainers.where((trainer) {
          // Female-only filter
          if (_showFemaleOnly && trainer.gender != 'female') {
            return false;
          }

          // Service filter
          if (_selectedCategory != 'All' && trainer.primaryService != _selectedCategory) {
            return false;
          }

          return true;
        }).toList();

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

              TrainerMatchingCard(
                onTap: () {
                  // Connect to concierge matching flow later.
                },
              ),
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
              if (index == 0) ...[
                const SizedBox(height: 24),

                TrainerMatchingCard(
                  onTap: () {
                    // We’ll connect this to the concierge
                    // request flow next.
                  },
                ),
              ],
              if (index != filteredTrainers.length - 1) const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }
}
