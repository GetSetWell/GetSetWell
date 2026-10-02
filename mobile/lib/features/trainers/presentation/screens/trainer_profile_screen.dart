import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_specialty_card.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_summary.dart';

import '../widgets/trainer_language_pill.dart';
import '../widgets/trainer_session_detail_row.dart';
import '../widgets/trainer_verification_row.dart';
import '../widgets/trainer_verification_sheet.dart';

class TrainerProfileScreen extends StatelessWidget {
  const TrainerProfileScreen({super.key, required this.trainer});

  final Trainer trainer;

  double get _sessionRate {
    return trainer.pricePerSession?.toDouble() ?? 0;
  }

  double get _serviceFee {
    return _sessionRate * 0.05;
  }

  double get _totalPrice {
    return _sessionRate + _serviceFee;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTrainerSummary(context),

                    const SizedBox(height: 12),

                    TrainerLocation(location: trainer.serviceArea ?? 'Dubai'),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: trainer.languages
                          .map((language) => TrainerLanguagePill(label: language))
                          .toList(),
                    ),

                    const SizedBox(height: 24),

                    TrainerVerificationRow(
                      onTap: () {
                        TrainerVerificationSheet.show(
                          context,
                          trainerName: trainer.fullName,
                          items: trainer.verificationChecks,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    _buildGoodFitSection(context),

                    const SizedBox(height: 24),

                    _buildSpecialties(context),

                    const SizedBox(height: 24),

                    _buildSessionDetails(context),

                    const SizedBox(height: 24),

                    _buildAbout(context),

                    const SizedBox(height: 24),
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
          if (trainer.profileImageUrl != null && trainer.profileImageUrl!.isNotEmpty)
            Image.network(
              trainer.profileImageUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 0.78, 1],
                colors: [Colors.transparent, Color(0x99000D1B), GSWColors.backgroundPrimary],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: GSWColors.borderSecondary),
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                  child: IconButton(
                    onPressed: () {
                      context.pop();
                    },
                    icon: SvgPicture.asset(
                      GSWIcons.arrowheadLeft,
                      width: 30,
                      height: 30,
                      colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
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
  // TRAINER SUMMARY
  // ---------------------------------------------------------------------------

  Widget _buildTrainerSummary(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trainer.fullName.toUpperCase(),
                style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textPrimary),
              ),

              const SizedBox(height: 4),

              Text(
                trainer.primaryService ?? '',
                style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'AED ${_formatMoney(_sessionRate)}',
              style: GSWTextStyles.displaySmall.copyWith(color: GSWColors.textAccent),
            ),

            Text(
              '/session',
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 2),

            Text(
              'AED ${_formatMoney(_totalPrice)} total',
              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GOOD FIT
  // ---------------------------------------------------------------------------

  Widget _buildGoodFitSection(BuildContext context) {
    if (trainer.fitPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A good fit if',
          style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int index = 0; index < trainer.fitPoints.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textAccent),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        trainer.fitPoints[index].text,
                        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                      ),
                    ),
                  ],
                ),

                if (index != trainer.fitPoints.length - 1) const SizedBox(height: 8),
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
        return GSWIcons.yoga;
    }
  }

  Widget _buildSpecialties(BuildContext context) {
    if (trainer.specialties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialities',
          style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
        ),

        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trainer.specialties.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.18,
          ),
          itemBuilder: (context, index) {
            final specialty = trainer.specialties[index];

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
  // SESSION DETAILS
  // ---------------------------------------------------------------------------

  Widget _buildSessionDetails(BuildContext context) {
    final hasSessionDetails =
        trainer.sessionDurationMinutes != null ||
        trainer.sessionFormat != null ||
        trainer.sessionLocations != null ||
        trainer.sessionScheduleNote != null ||
        trainer.paymentNote != null;

    if (!hasSessionDetails) {
      return const SizedBox.shrink();
    }

    final durationAndFormat = [
      if (trainer.sessionDurationMinutes != null) 'Up to ${trainer.sessionDurationMinutes} minutes',
      if (trainer.sessionFormat != null) trainer.sessionFormat!,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How sessions work',
          style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (durationAndFormat.isNotEmpty)
                TrainerSessionDetailRow(iconPath: GSWIcons.clock, text: durationAndFormat),

              if (trainer.sessionLocations != null) ...[
                const SizedBox(height: 8),

                TrainerSessionDetailRow(
                  iconPath: GSWIcons.location,
                  text: trainer.sessionLocations!,
                ),
              ],

              if (trainer.sessionScheduleNote != null) ...[
                const SizedBox(height: 8),

                TrainerSessionDetailRow(
                  iconPath: GSWIcons.calendar,
                  text: trainer.sessionScheduleNote!,
                ),
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

  Widget _buildAbout(BuildContext context) {
    if (trainer.bio == null || trainer.bio!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary)),

        const SizedBox(height: 8),

        Text(
          trainer.bio!,
          style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKING FOOTER
  // ---------------------------------------------------------------------------

  Widget _buildBookingFooter(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: GSWColors.surfacePrimary),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AED ${_formatMoney(_sessionRate)}',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: GSWColors.textAccent),
                      ),

                      Text(
                        '/session',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'AED ${_formatMoney(_totalPrice)} total',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: GSWColors.textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),

                  Expanded(
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
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Session fee refunded if you cancel 24 hours or more before',
                textAlign: TextAlign.center,
                style:
                    (Theme.of(context).extension<GSWTypography>()?.labelExtraSmall ??
                            GSWTextStyles.labelExtraSmall)
                        .copyWith(color: GSWColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
