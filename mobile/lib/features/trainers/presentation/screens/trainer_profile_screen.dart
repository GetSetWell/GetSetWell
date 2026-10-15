import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/domain/models/trainer_specialty.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_photo.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_specialty_card.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_summary.dart';

import '../widgets/trainer_language_pill.dart';
import '../widgets/trainer_session_detail_row.dart';
import '../widgets/trainer_verification_row.dart';
import '../widgets/trainer_verification_sheet.dart';

/// Figma 8.4 Trainer profile (818:3723).
class TrainerProfileScreen extends StatelessWidget {
  const TrainerProfileScreen({super.key, required this.trainer});

  final Trainer trainer;

  /// Session rate before the fee. Null when the trainer has no rate yet.
  double? get _sessionRate => trainer.pricePerSession;

  /// Specialities that may be shown. Anything rehabilitation-related is never
  /// displayed (v1.2 policy).
  List<TrainerSpecialty> get _visibleSpecialties {
    return trainer.specialties.where((specialty) {
      final slug = specialty.slug.toLowerCase();
      final name = specialty.name.toLowerCase();

      return !slug.contains('rehab') && !name.contains('rehab');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final showChecks = TrainerVerificationSheet.hasChecks(trainer.verificationChecks);
    final languages = trainer.languages.where((language) => language.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(context),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrainerNameAndPrice(
                      name: trainer.fullName,
                      service: trainer.primaryService ?? '',
                      price: _sessionRate,
                      large: true,
                    ),

                    const SizedBox(height: 12),

                    TrainerLocation(
                      location: trainer.serviceArea?.trim().isNotEmpty == true
                          ? trainer.serviceArea!
                          : 'Dubai',
                    ),

                    if (languages.isNotEmpty) ...[
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: languages
                            .map((language) => TrainerLanguagePill(label: language))
                            .toList(),
                      ),
                    ],

                    if (showChecks) ...[
                      const SizedBox(height: 24),

                      TrainerVerificationRow(
                        onTap: () {
                          TrainerVerificationSheet.show(
                            context,
                            trainerName: trainer.fullName,
                            items: trainer.verificationChecks,
                            closeLabel: 'Back to profile',
                          );
                        },
                      ),
                    ],

                    ..._section(_buildGoodFitSection()),
                    ..._section(_buildSpecialties()),
                    ..._section(_buildSessionDetails()),
                    ..._section(_buildAbout()),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBookingFooter(context),
    );
  }

  List<Widget> _section(Widget? child) {
    if (child == null) return const <Widget>[];

    return [const SizedBox(height: 24), child];
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary, height: 1),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------------

  Widget _buildHero(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TrainerPhoto(name: trainer.fullName, imageUrl: trainer.profileImageUrl),

          // Figma: gradient covers the lower 178px (from y 142 of 320),
          // transparent to 50% at the midpoint to solid Background/Primary.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.44, 0.72, 1],
                colors: [
                  GSWColors.backgroundPrimary.withValues(alpha: 0),
                  GSWColors.backgroundPrimary.withValues(alpha: 0.5),
                  GSWColors.backgroundPrimary,
                ],
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 0, 0),
                child: Material(
                  color: GSWColors.backgroundPrimary.withValues(alpha: 0.4),
                  shape: const CircleBorder(side: BorderSide(color: GSWColors.borderSecondary)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: SvgPicture.asset(
                          GSWIcons.arrowheadLeft,
                          width: 30,
                          height: 30,
                          semanticsLabel: 'Back',
                          colorFilter: const ColorFilter.mode(
                            GSWColors.iconAccent,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GOOD FIT
  // ---------------------------------------------------------------------------

  Widget? _buildGoodFitSection() {
    final points = trainer.fitPoints.where((point) => point.text.trim().isNotEmpty).toList();

    if (points.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('A good fit if'),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int index = 0; index < points.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: GSWColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        points[index].text,
                        style: GSWTextStyles.bodyMedium.copyWith(
                          color: GSWColors.textSecondary,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ],
                ),

                if (index != points.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SPECIALITIES
  // ---------------------------------------------------------------------------

  String _specialtyIcon(String slug) {
    switch (slug) {
      case 'beginner-yoga':
        return GSWIcons.yoga;
      case 'mobility':
        return GSWIcons.mobility;
      case 'pre-postnatal':
        return GSWIcons.prePostNatal;
      case 'core-strength':
        return GSWIcons.coreStrength;
      case 'strength-training':
        return GSWIcons.dumbell;
      case 'muscle-building':
        return GSWIcons.muscleBuilding;
      case 'conditioning':
        return GSWIcons.conditioning;
      case 'fat-loss':
        return GSWIcons.fatLoss;
      case 'functional-training':
        return GSWIcons.functionalTraining;
      case 'general-fitness':
        return GSWIcons.generalFitness;
      default:
        return GSWIcons.generalFitness;
    }
  }

  Widget? _buildSpecialties() {
    final specialties = _visibleSpecialties;

    if (specialties.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Specialities'),

        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: specialties.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 80,
          ),
          itemBuilder: (context, index) {
            final specialty = specialties[index];

            return TrainerSpecialtyCard(
              label: specialty.name,
              iconPath: _specialtyIcon(specialty.slug),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HOW SESSIONS WORK
  // ---------------------------------------------------------------------------

  Widget _buildSessionDetails() {
    // Sessions are fixed at 60 minutes under the current policy.
    final format = trainer.sessionFormat?.trim();
    final durationAndFormat = format == null || format.isEmpty
        ? '60 minutes, one to one'
        : '60 minutes, ${format[0].toLowerCase()}${format.substring(1)}';

    final locations = trainer.sessionLocations?.trim() ?? '';
    final schedule = trainer.sessionScheduleNote?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('How sessions work'),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
          ),
          child: Column(
            children: [
              TrainerSessionDetailRow(iconPath: GSWIcons.clock, text: durationAndFormat),

              if (locations.isNotEmpty) ...[
                const SizedBox(height: 8),
                TrainerSessionDetailRow(iconPath: GSWIcons.location, text: locations),
              ],

              if (schedule.isNotEmpty) ...[
                const SizedBox(height: 8),
                TrainerSessionDetailRow(iconPath: GSWIcons.calendar, text: schedule),
              ],

              const SizedBox(height: 8),

              const TrainerSessionDetailRow(
                iconPath: GSWIcons.cash,
                text: 'Paid in the app when you book, plus a 5% service fee',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ABOUT
  // ---------------------------------------------------------------------------

  Widget? _buildAbout() {
    final bio = trainer.bio?.trim() ?? '';

    if (bio.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('About'),

        const SizedBox(height: 8),

        Text(
          bio,
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKING FOOTER
  // Figma: 12px top padding, price block (Bebas 26 rate, /session 12/16,
  // total 11/15), 24px gap, 40px button, 8px, refund note 11/14.
  // The row wraps rather than clipping on narrow screens.
  // ---------------------------------------------------------------------------

  Widget _buildBookingFooter(BuildContext context) {
    final rate = _sessionRate;

    return Container(
      // Figma 8.4 footer: Surface/Primary fill, no divider.
      color: GSWColors.surfacePrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (rate != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          GSWMoney.aed(rate),
                          style: GSWTextStyles.headingSmall.copyWith(
                            color: GSWColors.textAccent,
                            height: 1,
                          ),
                        ),
                        Text(
                          '/session',
                          style: GSWTextStyles.bodySmall.copyWith(
                            color: GSWColors.textSecondary,
                            height: 16 / 12,
                          ),
                        ),
                        Text(
                          '${GSWMoney.aed(GSWMoney.totalWithFee(rate))} total',
                          style: GSWTextStyles.bodyExtraSmall.copyWith(
                            color: GSWColors.textSecondary,
                            height: 15 / 11,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 24),
                  ],

                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: GSWButton(
                        size: GSWButtonSize.medium,
                        label: 'Book a session',
                        onPressed: () {
                          context.push(
                            GSWRoutes.bookingRequest,
                            extra: BookingRequestRouteData(trainer: trainer),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Session fee refunded if you cancel 24 hours or more before',
                textAlign: TextAlign.center,
                style: GSWTextStyles.labelExtraSmall.copyWith(
                  color: GSWColors.textSecondary,
                  height: 14 / 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
