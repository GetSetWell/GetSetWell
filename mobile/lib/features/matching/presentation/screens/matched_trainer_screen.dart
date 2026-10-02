import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_row.dart';
import 'package:mobile/features/trainers/presentation/widgets/trainer_verification_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchedTrainerScreen extends StatefulWidget {
  const MatchedTrainerScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<MatchedTrainerScreen> createState() => _MatchedTrainerScreenState();
}

class _MatchedTrainerScreenState extends State<MatchedTrainerScreen> {
  late final Future<_MatchedTrainerData> _dataFuture;

  @override
  void initState() {
    super.initState();

    _dataFuture = _loadData();
  }

  Future<_MatchedTrainerData> _loadData() async {
    final client = Supabase.instance.client;

    final requestRow = await client
        .from('booking_requests')
        .select('''

          id,

          trainer_id,
          status,

          goal,

          preferred_days,

          preferred_time,

          preferred_area,

          budget_min,

          budget_max,

          match_outcome,

          match_reason,

          matched_at,

          training_locations (

            name

          )

        ''')
        .eq('id', widget.requestId)
        .single();

    final request = Map<String, dynamic>.from(requestRow);

    final status = request['status']?.toString().trim().toLowerCase() ?? '';

    if (status != 'matched') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        context.go(GSWRoutes.conciergeRequestStatus, extra: widget.requestId);
      });

      throw Exception('Request is no longer matched.');
    }

    final trainerId = request['trainer_id']?.toString().trim() ?? '';

    if (trainerId.isEmpty) {
      throw Exception('Matched request has no trainer.');
    }

    final trainerRepository = TrainerRepository(client);

    final trainers = await trainerRepository.getTrainers();

    Trainer? matchedTrainer;

    for (final trainer in trainers) {
      if (trainer.id == trainerId) {
        matchedTrainer = trainer;

        break;
      }
    }

    if (matchedTrainer == null) {
      throw Exception('Matched trainer could not be found.');
    }

    return _MatchedTrainerData(request: request, trainer: matchedTrainer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: FutureBuilder<_MatchedTrainerData>(
        future: _dataFuture,

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SafeArea(
              child: Center(child: CircularProgressIndicator(color: GSWColors.primary)),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _buildErrorState();
          }

          return _buildContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildContent(_MatchedTrainerData data) {
    final request = data.request;

    final trainer = data.trainer;

    final fullName = trainer.fullName;

    final firstName = fullName.split(RegExp(r'\s+')).first;

    final gender = trainer.gender?.trim().toLowerCase() ?? '';

    final profileImage = trainer.profileImageUrl;

    final price = trainer.pricePerSession;

    final serviceArea = trainer.serviceArea?.trim() ?? '';

    final availability = trainer.availabilityNote?.trim() ?? '';

    final subjectPronoun = gender == 'female'
        ? 'She'
        : gender == 'male'
        ? 'He'
        : 'They';

    final objectPronoun = gender == 'female'
        ? 'her'
        : gender == 'male'
        ? 'him'
        : 'them';

    final possessivePronoun = gender == 'female'
        ? 'her'
        : gender == 'male'
        ? 'his'
        : 'their';

    final goal = request['goal']?.toString().trim() ?? '';

    final preferredTime = request['preferred_time']?.toString().trim() ?? '';

    final preferredArea = request['preferred_area']?.toString().trim() ?? '';

    final rawDays = request['preferred_days'];

    final preferredDays = rawDays is List
        ? rawDays.map((day) => day.toString()).toList()
        : <String>[];

    final location = request['training_locations'];

    String trainingLocation = '';

    if (location is Map) {
      trainingLocation = location['name']?.toString().trim() ?? '';
    }

    final budgetMin = request['budget_min'] as num?;

    final budgetMax = request['budget_max'] as num?;

    final matchOutcome = request['match_outcome']?.toString().trim().toLowerCase() ?? '';

    final matchReason = request['match_reason']?.toString().trim() ?? '';

    final matchedAt = DateTime.tryParse(request['matched_at']?.toString() ?? '');

    final isOutsideBudget = matchOutcome == 'outside_budget';

    final serviceFee = price == null ? null : price * 0.05;

    final total = price == null ? null : price + serviceFee!;

    final budgetDifference = price != null && budgetMax != null && price > budgetMax
        ? price - budgetMax
        : null;

    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),

            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _buildHero(fullName: fullName, imagePath: profileImage),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    'We picked $firstName',

                                    style: GSWTextStyles.titleLarge.copyWith(
                                      color: GSWColors.textPrimary,

                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    preferredArea.isNotEmpty
                                        ? 'Personal training · $preferredArea'
                                        : serviceArea.isNotEmpty
                                        ? 'Personal training · $serviceArea'
                                        : 'Personal training',

                                    style: GSWTextStyles.bodySmall.copyWith(
                                      color: GSWColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            _buildViewProfileButton(),
                          ],
                        ),

                        const SizedBox(height: 20),

                        _buildFitCard(
                          goal: goal,

                          preferredDays: preferredDays,

                          preferredTime: preferredTime,

                          preferredArea: preferredArea,

                          trainingLocation: trainingLocation,

                          budgetMin: budgetMin,

                          budgetMax: budgetMax,

                          trainerPrice: price,

                          subjectPronoun: subjectPronoun,

                          possessivePronoun: possessivePronoun,

                          availability: availability,

                          serviceArea: serviceArea,

                          isOutsideBudget: isOutsideBudget,

                          budgetDifference: budgetDifference,

                          matchReason: matchReason,

                          firstName: firstName,
                        ),

                        const SizedBox(height: 18),

                        _buildCostCard(
                          price: price,

                          serviceFee: serviceFee,

                          total: total,

                          area: preferredArea.isNotEmpty ? preferredArea : serviceArea,
                        ),

                        const SizedBox(height: 18),

                        TrainerVerificationRow(
                          onTap: () {
                            TrainerVerificationSheet.show(
                              context,

                              trainerName: trainer.fullName,

                              items: trainer.verificationChecks,
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'We recommend on what you told us and each trainer\'s experience, area, availability and price. No trainer can pay to be recommended.',

                          style: GSWTextStyles.bodyExtraSmall.copyWith(
                            color: GSWColors.textSecondary,

                            height: 1.45,
                          ),
                        ),

                        if (isOutsideBudget) ...[
                          const SizedBox(height: 24),

                          Center(
                            child: TextButton(
                              onPressed: () {
                                _showNotQuiteRightSheet(firstName: firstName);
                              },

                              child: Text(
                                'Not quite right?',

                                style: GSWTextStyles.bodyMedium.copyWith(
                                  color: GSWColors.primary,

                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (matchedAt != null && !isOutsideBudget) ...[
                          const SizedBox(height: 16),

                          Text(
                            'Picked for you on ${_formatDate(matchedAt)}',

                            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        _buildBottomActions(
          firstName: firstName,

          objectPronoun: objectPronoun,

          isOutsideBudget: isOutsideBudget,

          trainer: trainer,
        ),
      ],
    );
  }

  Widget _buildHero({required String fullName, required String? imagePath}) {
    final imageUrl = _trainerImageUrl(imagePath);

    return SizedBox(
      width: double.infinity,

      height: 270,

      child: Stack(
        fit: StackFit.expand,

        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,

              fit: BoxFit.cover,

              alignment: const Alignment(0, -0.9),

              errorBuilder: (context, error, stackTrace) {
                return _buildImageFallback(fullName);
              },
            )
          else
            _buildImageFallback(fullName),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,

                end: Alignment.bottomCenter,

                stops: [0, 0.68, 1],

                colors: [Colors.transparent, Colors.transparent, GSWColors.backgroundPrimary],
              ),
            ),
          ),

          Positioned(
            left: 20,

            top: MediaQuery.of(context).padding.top + 18,

            child: _buildBackButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => context.pop(),

      borderRadius: BorderRadius.circular(999),

      child: Container(
        width: 44,

        height: 44,

        decoration: BoxDecoration(
          color: GSWColors.backgroundPrimary,

          shape: BoxShape.circle,

          border: Border.all(color: GSWColors.borderSecondary),
        ),

        child: const Icon(Icons.chevron_left, color: GSWColors.primary, size: 28),
      ),
    );
  }

  Widget _buildViewProfileButton() {
    return SizedBox(
      height: 38,

      child: OutlinedButton(
        onPressed: () {
          // Trainer profile routing comes next.
        },

        style: OutlinedButton.styleFrom(
          backgroundColor: GSWColors.surfaceElevated,

          foregroundColor: GSWColors.textPrimary,

          side: const BorderSide(color: GSWColors.borderSecondary),

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),

          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),

        child: Text(
          'View profile',

          style: GSWTextStyles.bodySmall.copyWith(
            color: GSWColors.textPrimary,

            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFitCard({
    required String goal,

    required List<String> preferredDays,

    required String preferredTime,

    required String preferredArea,

    required String trainingLocation,

    required num? budgetMin,

    required num? budgetMax,

    required num? trainerPrice,

    required String subjectPronoun,

    required String possessivePronoun,

    required String availability,

    required String serviceArea,

    required bool isOutsideBudget,

    required num? budgetDifference,

    required String matchReason,

    required String firstName,
  }) {
    final goalLabel = _goalHeadline(goal);

    final scheduleLabel = _scheduleLabel(preferredDays, preferredTime);

    final areaLabel = preferredArea.isNotEmpty
        ? 'A gym in $preferredArea'
        : trainingLocation.isNotEmpty
        ? trainingLocation
        : serviceArea;

    final budgetLabel = budgetMin != null && budgetMax != null
        ? 'AED ${_money(budgetMin)} to ${_money(budgetMax)} a session'
        : 'Your preferred budget';

    final fitCount = isOutsideBudget ? 3 : 4;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_capitalize(subjectPronoun.toLowerCase()) == 'She' ? 'How she fits' : 'How he fits'} what you asked for',

                  style: GSWTextStyles.bodyMedium.copyWith(
                    color: GSWColors.textPrimary,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                '$fitCount of 4',

                style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildFitRow(
            title: goalLabel,

            subtitle: 'Personal training is what ${subjectPronoun.toLowerCase()} does',

            warning: false,
          ),

          const SizedBox(height: 16),

          _buildFitRow(
            title: scheduleLabel,

            subtitle: availability.isNotEmpty
                ? availability
                : '$subjectPronoun has availability around those times',

            warning: false,
          ),

          const SizedBox(height: 16),

          _buildFitRow(
            title: areaLabel,

            subtitle: serviceArea.isNotEmpty
                ? '$subjectPronoun trains in $serviceArea'
                : '$subjectPronoun trains around your preferred area',

            warning: false,
          ),

          const SizedBox(height: 16),

          _buildFitRow(
            title: budgetLabel,

            subtitle: trainerPrice == null
                ? 'Price confirmed before booking'
                : isOutsideBudget
                ? '$subjectPronoun charges AED ${_money(trainerPrice)}'
                : 'AED ${_money(trainerPrice)}, inside your budget',

            warning: isOutsideBudget,

            trailing: isOutsideBudget && budgetDifference != null
                ? 'AED ${_money(budgetDifference)} over'
                : null,
          ),

          if (matchReason.isNotEmpty) ...[
            const SizedBox(height: 16),

            Divider(height: 1, color: GSWColors.neutral700),

            const SizedBox(height: 14),

            Text(
              isOutsideBudget ? 'Why someone above your budget' : 'Why $firstName',

              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              matchReason,

              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textPrimary, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFitRow({
    required String title,

    required String subtitle,

    required bool warning,

    String? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          width: 18,

          height: 18,

          margin: const EdgeInsets.only(top: 1),

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            border: Border.all(color: warning ? GSWColors.textPrimary : GSWColors.textPrimary),
          ),

          child: Icon(
            warning ? Icons.priority_high : Icons.check,

            size: 12,

            color: GSWColors.textPrimary,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,

                      style: GSWTextStyles.bodySmall.copyWith(
                        color: GSWColors.textPrimary,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  if (trailing != null) ...[
                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

                      decoration: BoxDecoration(
                        color: GSWColors.surfaceInteractive,

                        borderRadius: BorderRadius.circular(999),
                      ),

                      child: Text(
                        trailing,

                        style: GSWTextStyles.bodyExtraSmall.copyWith(
                          color: GSWColors.textPrimary,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,

                style: GSWTextStyles.bodyExtraSmall.copyWith(
                  color: GSWColors.textSecondary,

                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostCard({
    required num? price,

    required num? serviceFee,

    required num? total,

    required String area,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'What a session costs',

            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textPrimary,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          _buildPriceRow('Session, 60 minutes', price == null ? '—' : 'AED ${_moneyFixed(price)}'),

          const SizedBox(height: 14),

          _buildPriceRow(
            'Service fee (5%)',

            serviceFee == null ? '—' : 'AED ${_moneyFixed(serviceFee)}',
          ),

          const SizedBox(height: 12),

          Divider(height: 1, color: GSWColors.neutral700),

          const SizedBox(height: 14),

          _buildPriceRow('Total', total == null ? '—' : 'AED ${_moneyFixed(total)}', bold: true),

          if (area.isNotEmpty) ...[
            const SizedBox(height: 10),

            Text(
              'In $area. You choose the time next.',

              style: GSWTextStyles.bodyExtraSmall.copyWith(color: GSWColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,

            style: GSWTextStyles.bodySmall.copyWith(
              color: bold ? GSWColors.textPrimary : GSWColors.textSecondary,

              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),

        Text(
          value,

          style: GSWTextStyles.bodySmall.copyWith(
            color: GSWColors.textPrimary,

            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions({
    required String firstName,

    required String objectPronoun,

    required bool isOutsideBudget,

    required trainer,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

      color: GSWColors.surfacePrimary,

      child: SafeArea(
        top: false,

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            GSWButton(
              size: GSWButtonSize.large,

              variant: GSWButtonVariant.primary,

              label: 'Book a session with $firstName',

              onPressed: () {
                context.push(
                  GSWRoutes.bookingRequest,

                  extra: BookingRequestRouteData(
                    trainer: trainer,

                    sourceConciergeRequestId: widget.requestId,
                  ),
                );
              },
            ),

            if (isOutsideBudget) ...[
              const SizedBox(height: 8),

              GSWButton(
                size: GSWButtonSize.large,

                variant: GSWButtonVariant.secondary,

                label: 'Find someone within my budget',

                onPressed: () {
                  _showNotQuiteRightSheet(firstName: firstName);
                },
              ),
            ] else ...[
              const SizedBox(height: 8),

              TextButton(
                onPressed: () {
                  _showNotQuiteRightSheet(firstName: firstName);
                },

                child: Text(
                  'Not quite right?',

                  style: GSWTextStyles.bodyMedium.copyWith(
                    color: GSWColors.primary,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showNotQuiteRightSheet({required String firstName}) async {
    final noteController = TextEditingController();

    String selectedReason = 'days_times';

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: GSWColors.backgroundPrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: GSWColors.borderSecondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'What\'s not right?',
                        style: GSWTextStyles.titleLarge.copyWith(
                          color: GSWColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Tell us and we\'ll keep looking. There\'s no obligation to book.',
                        style: GSWTextStyles.bodySmall.copyWith(
                          color: GSWColors.textSecondary,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: GSWColors.surfacePrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            _buildReasonOption(
                              label: 'The price',
                              value: 'price',
                              selectedValue: selectedReason,
                              onTap: () {
                                setSheetState(() {
                                  selectedReason = 'price';
                                });
                              },
                            ),

                            _buildSheetDivider(),

                            _buildReasonOption(
                              label: 'The days or times',
                              value: 'days_times',
                              selectedValue: selectedReason,
                              onTap: () {
                                setSheetState(() {
                                  selectedReason = 'days_times';
                                });
                              },
                            ),

                            _buildSheetDivider(),

                            _buildReasonOption(
                              label: 'The area or place',
                              value: 'area',
                              selectedValue: selectedReason,
                              onTap: () {
                                setSheetState(() {
                                  selectedReason = 'area';
                                });
                              },
                            ),

                            _buildSheetDivider(),

                            _buildReasonOption(
                              label: 'I\'d like a different trainer',
                              value: 'trainer',
                              selectedValue: selectedReason,
                              onTap: () {
                                setSheetState(() {
                                  selectedReason = 'trainer';
                                });
                              },
                            ),

                            _buildSheetDivider(),

                            _buildReasonOption(
                              label: 'Something else',
                              value: 'other',
                              selectedValue: selectedReason,
                              onTap: () {
                                setSheetState(() {
                                  selectedReason = 'other';
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Anything to add? (optional)',
                        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'For example, evenings would suit me better',
                          hintStyle: GSWTextStyles.bodyMedium.copyWith(
                            color: GSWColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: GSWColors.surfacePrimary,
                          contentPadding: const EdgeInsets.all(14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: GSWColors.borderSecondary),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: GSWColors.primary),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Please don\'t include health details.',
                        style: GSWTextStyles.bodyExtraSmall.copyWith(
                          color: GSWColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: GSWButton(
                          size: GSWButtonSize.large,
                          variant: GSWButtonVariant.primary,
                          label: 'Send and keep looking',
                          onPressed: () async {
                            try {
                              FocusManager.instance.primaryFocus?.unfocus();

                              await Supabase.instance.client.rpc(
                                'request_concierge_rematch',
                                params: {
                                  'p_request_id': widget.requestId,
                                  'p_reason': selectedReason,
                                  'p_note': noteController.text.trim().isEmpty
                                      ? null
                                      : noteController.text.trim(),
                                },
                              );

                              if (!sheetContext.mounted) return;

                              // Only close the bottom sheet here.
                              Navigator.of(sheetContext).pop(true);
                            } catch (error) {
                              debugPrint('Request concierge rematch failed: $error');

                              if (!sheetContext.mounted) return;

                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'We could not update your request. Please try again.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(false);
                          },
                          child: Text(
                            'Keep $firstName as my match',
                            style: GSWTextStyles.bodyMedium.copyWith(
                              color: GSWColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();

    if (submitted != true || !mounted) {
      return;
    }

    // Return the successful rematch result to YourMatchScreen.
    context.pop(true);
  }

  Widget _buildReasonOption({
    required String label,

    required String value,

    required String selectedValue,

    required VoidCallback onTap,
  }) {
    final selected = value == selectedValue;

    return InkWell(
      onTap: onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),

        child: Row(
          children: [
            Expanded(
              child: Text(
                label,

                style: GSWTextStyles.bodySmall.copyWith(
                  color: GSWColors.textPrimary,

                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),

            Container(
              width: 20,

              height: 20,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: selected ? GSWColors.primary : GSWColors.textSecondary,

                  width: selected ? 2 : 1.5,
                ),
              ),

              child: selected
                  ? Center(
                      child: Container(
                        width: 8,

                        height: 8,

                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,

                          color: GSWColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),

      child: Divider(height: 1, color: GSWColors.neutral700),
    );
  }

  Widget _buildImageFallback(String name) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      color: GSWColors.surfaceInteractive,

      alignment: Alignment.center,

      child: Text(
        initials.isEmpty ? 'T' : initials,

        style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.primary),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Text(
            'We could not load your trainer.',

            textAlign: TextAlign.center,

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),
        ),
      ),
    );
  }

  String? _trainerImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    return Supabase.instance.client.storage.from('trainer-images').getPublicUrl(imagePath);
  }

  String _goalHeadline(String value) {
    switch (value.trim().toLowerCase()) {
      case 'lose weight':
        return 'Lose weight and build a routine';

      case 'get stronger':
        return 'Get stronger and build a routine';

      case 'move better':
        return 'Move better and build a routine';

      case 'back after a break':
        return 'Get back into a routine';

      case 'pre or postnatal':
        return 'Build a supported routine';

      default:
        return _capitalize(value);
    }
  }

  String _scheduleLabel(List<String> days, String time) {
    final shortDays = days.map(_shortDay).toList();

    String dayText = '';

    if (shortDays.length == 1) {
      dayText = shortDays.first;
    } else if (shortDays.length == 2) {
      dayText = '${shortDays[0]} and ${shortDays[1]}';
    } else if (shortDays.length > 2) {
      dayText = '${shortDays.sublist(0, shortDays.length - 1).join(', ')} and ${shortDays.last}';
    }

    final normalizedTime = time.trim().toLowerCase();

    final timeText = switch (normalizedTime) {
      'morning' => 'mornings',
      'afternoon' => 'afternoons',
      'evening' => 'evenings',

      _ => normalizedTime,
    };

    if (dayText.isEmpty) {
      return _capitalize(timeText);
    }

    return '$dayText $timeText';
  }

  String _shortDay(String value) {
    switch (value.trim().toLowerCase()) {
      case 'monday':
        return 'Mon';

      case 'tuesday':
        return 'Tue';

      case 'wednesday':
        return 'Wed';

      case 'thursday':
        return 'Thu';

      case 'friday':
        return 'Fri';

      case 'saturday':
        return 'Sat';

      case 'sunday':
        return 'Sun';

      default:
        return value;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  String _capitalize(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  String _money(num value) {
    final number = value.toDouble();

    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }

    return number.toStringAsFixed(2);
  }

  String _moneyFixed(num value) {
    return value.toDouble().toStringAsFixed(2);
  }
}

class _MatchedTrainerData {
  const _MatchedTrainerData({required this.request, required this.trainer});

  final Map<String, dynamic> request;

  final Trainer trainer;
}
