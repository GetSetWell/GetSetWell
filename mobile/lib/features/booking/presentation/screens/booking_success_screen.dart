import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_success_data.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.data});

  final BookingSuccessData data;

  static const String _whatsAppNumber = '971505251393';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: GSWColors.backgroundPrimary,
      ),
      child: Scaffold(
        backgroundColor: GSWColors.backgroundPrimary,
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: const _NoScrollEffectBehavior(),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: switch (data) {
                ConciergeMatchSuccessData conciergeData =>
                  _buildConciergeSuccess(context, conciergeData),
                TrainerRequestSuccessData trainerData => _buildTrainerSuccess(
                  context,
                  trainerData,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Concierge success
  // ---------------------------------------------------------------------------

  Widget _buildConciergeSuccess(
    BuildContext context,
    ConciergeMatchSuccessData successData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConciergeSuccessHeader(),

        const SizedBox(height: 24),

        _buildConciergeRequestCard(successData),

        const SizedBox(height: 22),

        Text(
          'What happens next',
          style: GSWTextStyles.titleExtraSmall.copyWith(
            color: GSWColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        const _ConciergeNextStepsCard(),

        const SizedBox(height: 24),

        _buildTalkNowCard(),

        const SizedBox(height: 48),

        _buildContactCopy(successData.referenceCode),

        const SizedBox(height: 24),

        GSWButton(
          size: GSWButtonSize.large,
          variant: GSWButtonVariant.secondary,
          label: 'Go to home',
          onPressed: () => _goToHome(context),
        ),

        const SizedBox(height: 8),

        GSWButton(
          size: GSWButtonSize.large,
          label: 'Open WhatsApp',
          leadingIcon: GSWIcons.whatsapp,
          onPressed: () => _openWhatsApp(context, successData.referenceCode),
        ),
      ],
    );
  }

  Widget _buildConciergeSuccessHeader() {
    return Column(
      children: [
        SvgPicture.asset(
          GSWIcons.chatCheck,
          width: 96,
          height: 96,
          colorFilter: const ColorFilter.mode(
            GSWColors.iconAccent,
            BlendMode.srcIn,
          ),
        ),

        const SizedBox(height: 24),

        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'REQUEST ',
                style: GSWTextStyles.displayLarge.copyWith(
                  color: GSWColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'SENT',
                style: GSWTextStyles.displayLarge.copyWith(
                  color: GSWColors.textAccent,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Nothing is booked. A person will read this and you’ll be notified via app & WhatsApp.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConciergeRequestCard(ConciergeMatchSuccessData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your request',
                  style: GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textSecondary,
                  ),
                ),
              ),
              Text(
                data.referenceCode,
                style: GSWTextStyles.titleExtraSmall.copyWith(
                  color: GSWColors.textAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(height: 1, color: GSWColors.borderDisabled),

          const SizedBox(height: 12),

          _SummaryRow(
            leftLabel: 'Goal',
            leftValue: data.goal,
            rightLabel: 'Days',
            rightValue: data.days,
          ),

          const SizedBox(height: 12),

          _SummaryRow(
            leftLabel: 'Time',
            leftValue: data.time,
            rightLabel: 'Where',
            rightValue: data.trainingLocation,
          ),

          const SizedBox(height: 12),

          _SummaryRow(
            leftLabel: 'Preferred Area',
            leftValue: data.preferredArea,
            rightLabel: 'Trainer preference',
            rightValue: _trainerPreferenceSummary(data),
            highlightRight: _hasTrainerPreference(data),
          ),
        ],
      ),
    );
  }

  bool _hasTrainerPreference(ConciergeMatchSuccessData data) {
    return data.trainerPreference != null || data.budget != null;
  }

  String _trainerPreferenceSummary(ConciergeMatchSuccessData data) {
    final parts = <String>[];

    final trainerPreference = data.trainerPreference?.trim();

    final budget = data.budget?.trim();

    if (trainerPreference != null && trainerPreference.isNotEmpty) {
      parts.add(trainerPreference);
    }

    if (budget != null && budget.isNotEmpty) {
      parts.add(budget);
    }

    if (parts.isEmpty) {
      return 'No preference';
    }

    return parts.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Specific trainer success
  // ---------------------------------------------------------------------------

  Widget _buildTrainerSuccess(
    BuildContext context,
    TrainerRequestSuccessData successData,
  ) {
    final firstName = _firstName(successData.trainerName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTrainerSuccessHeader(firstName),

        const SizedBox(height: 24),

        _buildTrainerRequestCard(successData),

        const SizedBox(height: 22),

        Text(
          'What happens next',
          style: GSWTextStyles.titleExtraSmall.copyWith(
            color: GSWColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        _TrainerNextStepsCard(trainerFirstName: firstName),

        const SizedBox(height: 24),

        _buildTalkNowCard(),

        const SizedBox(height: 24),

        _buildContactCopy(successData.referenceCode),

        const SizedBox(height: 24),

        GSWButton(
          size: GSWButtonSize.large,
          variant: GSWButtonVariant.secondary,
          label: 'Back to home',
          onPressed: () => _goToHome(context),
        ),

        const SizedBox(height: 8),

        GSWButton(
          size: GSWButtonSize.large,
          label: 'Open WhatsApp',
          leadingIcon: GSWIcons.whatsapp,
          onPressed: () => _openWhatsApp(context, successData.referenceCode),
        ),
      ],
    );
  }

  Widget _buildTrainerSuccessHeader(String firstName) {
    return Column(
      children: [
        SvgPicture.asset(
          GSWIcons.chatCheck,
          width: 96,
          height: 96,
          colorFilter: const ColorFilter.mode(
            GSWColors.iconAccent,
            BlendMode.srcIn,
          ),
        ),

        const SizedBox(height: 24),

        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'REQUEST ',
                style: GSWTextStyles.displayLarge.copyWith(
                  color: GSWColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'SENT',
                style: GSWTextStyles.displayLarge.copyWith(
                  color: GSWColors.textAccent,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'This is not a confirmed booking. We will check '
            '$firstName’s availability and get back to you on WhatsApp.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerRequestCard(TrainerRequestSuccessData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your request',
                  style: GSWTextStyles.titleExtraSmall.copyWith(
                    color: GSWColors.textSecondary,
                  ),
                ),
              ),
              Text(
                data.referenceCode,
                style: GSWTextStyles.titleExtraSmall.copyWith(
                  color: GSWColors.textAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(height: 1, color: GSWColors.borderDisabled),

          const SizedBox(height: 12),

          Text(
            data.trainerName,
            style: GSWTextStyles.titleExtraSmall.copyWith(
              color: GSWColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Container(height: 1, color: GSWColors.borderDisabled),

          const SizedBox(height: 12),

          _SummaryRow(
            leftLabel: 'Goal',
            leftValue: data.goal,
            rightLabel: 'Days',
            rightValue: data.days,
          ),

          const SizedBox(height: 12),

          _SummaryRow(
            leftLabel: 'Time',
            leftValue: data.time,
            rightLabel: 'Where',
            rightValue: data.trainingLocation,
          ),

          const SizedBox(height: 12),

          _SummaryRow(
            leftLabel: 'Preferred Area',
            leftValue: data.preferredArea,
            rightLabel: 'Rate',
            rightValue: data.rate,
            highlightRight: true,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared sections
  // ---------------------------------------------------------------------------

  Widget _buildTalkNowCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: GSWColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: GSWColors.borderDisabled),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prefer to talk now?',
            style: GSWTextStyles.titleExtraSmall.copyWith(
              color: GSWColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Open WhatsApp and your request reference is already in the '
            'message. You do not need to explain it again.',
            style: GSWTextStyles.bodySmall.copyWith(
              color: GSWColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCopy(String referenceCode) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Any questions? Email ',
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
            ),
          ),
          TextSpan(
            text: 'info@getsetwell.com',
            style: GSWTextStyles.labelMedium.copyWith(
              color: GSWColors.textPrimary,
            ),
          ),
          TextSpan(
            text: ' and quote $referenceCode.',
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _goToHome(BuildContext context) {
    context.go(GSWRoutes.home);
  }

  Future<void> _openWhatsApp(BuildContext context, String referenceCode) async {
    final message =
        "Hi GetSetWell, I'm following up on request $referenceCode.";

    final uri = Uri.https('wa.me', '/$_whatsAppNumber', {'text': message});

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not open WhatsApp. Please try again.'),
        ),
      );
    }
  }

  String _firstName(String fullName) {
    final trimmed = fullName.trim();

    if (trimmed.isEmpty) {
      return 'the trainer';
    }

    return trimmed.split(RegExp(r'\s+')).first;
  }
}

// -----------------------------------------------------------------------------
// Scroll behavior
// -----------------------------------------------------------------------------

class _NoScrollEffectBehavior extends ScrollBehavior {
  const _NoScrollEffectBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

// -----------------------------------------------------------------------------
// Summary
// -----------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.highlightRight = false,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final bool highlightRight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SummaryItem(label: leftLabel, value: leftValue),
        ),

        const SizedBox(width: 12),
        Expanded(
          child: _SummaryItem(
            label: rightLabel,
            value: rightValue,
            highlight: highlightRight,
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: GSWTextStyles.bodyMedium.copyWith(
            color: GSWColors.textSecondary,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: GSWTextStyles.bodyMedium.copyWith(
            color: highlight ? GSWColors.textAccent : GSWColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Concierge next steps
// -----------------------------------------------------------------------------

class _ConciergeNextStepsCard extends StatelessWidget {
  const _ConciergeNextStepsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          _NextStep(
            number: '1',
            title: 'We review your request',
            description:
                'Not a queue and not an auto reply. Usually the same day, '
                'and by the next morning at the latest.',
          ),

          SizedBox(height: 8),

          _NextStep(
            number: '2',
            title: 'We suggest who fits',
            description:
                'One trainer who fits best, with the session fee and why we picked them.',
          ),

          SizedBox(height: 8),

          _NextStep(
            number: '3',
            title: 'You decide',
            description:
                'Go ahead, ask for another option, or leave it. No obligation and no follow up calls.',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Trainer next steps
// -----------------------------------------------------------------------------

class _TrainerNextStepsCard extends StatelessWidget {
  const _TrainerNextStepsCard({required this.trainerFirstName});

  final String trainerFirstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const _NextStep(
            number: '1',
            title: 'We review your request',
            description:
                'Not a queue and not an auto reply. Usually the same day, '
                'and by the next morning at the latest.',
          ),

          const SizedBox(height: 8),

          _NextStep(
            number: '2',
            title: 'We message you on WhatsApp',
            description:
                'We confirm whether $trainerFirstName is free, agree the '
                'time and place, and answer anything you want to ask first.',
          ),

          const SizedBox(height: 8),

          _NextStep(
            number: '3',
            title: 'You decide',
            description:
                'Nothing is booked until you say so. You pay '
                '$trainerFirstName directly, after the session is agreed.',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared next-step row
// -----------------------------------------------------------------------------

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.borderFocused, width: 1),
          ),
          child: Text(
            number,
            style: GSWTextStyles.labelMedium.copyWith(
              color: GSWColors.textAccent,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: GSWColors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                description,
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: GSWColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
