import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class YourMatchScreen extends StatefulWidget {
  const YourMatchScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<YourMatchScreen> createState() => _YourMatchScreenState();
}

class _YourMatchScreenState extends State<YourMatchScreen> {
  late final Future<Map<String, dynamic>> _requestFuture;

  @override
  void initState() {
    super.initState();

    _requestFuture = _loadRequest();
  }

  Future<Map<String, dynamic>> _loadRequest() async {
    final row = await Supabase.instance.client
        .from('booking_requests')
        .select('''
          id,
          reference_code,
          goal,
          status,
          preferred_days,
          preferred_time,
          preferred_area,
          trainer_gender_preference,
          budget_min,
          budget_max,
          language_preference,
          message,
          trainer_id,
          match_outcome,
          match_reason,
          matched_at,
          training_locations (
            name
          ),
          trainers (
            full_name,
            profile_image_url,
            price_per_session
          )
          ''')
        .eq('id', widget.requestId)
        .single();

    return Map<String, dynamic>.from(row);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _requestFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Text(
                  'Could not load your match.',
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),
              );
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> request) {
    final rawDays = request['preferred_days'];

    final days = rawDays is List ? rawDays.map((day) => _shortDay(day.toString())).join(', ') : '';

    final referenceCode = request['reference_code']?.toString().trim() ?? 'Request';

    final goal = _goalHeadline(request['goal']?.toString());

    final time = _capitalize(request['preferred_time']?.toString() ?? '');

    final preferredArea = request['preferred_area']?.toString().trim() ?? '';

    final location = request['training_locations'];
    final matchOutcome = request['match_outcome']?.toString().trim().toLowerCase() ?? '';

    final requestId = request['id']?.toString().trim() ?? '';
    String trainingLocation = '';

    if (location is Map) {
      trainingLocation = location['name']?.toString().trim() ?? '';
    }

    final preference = request['trainer_gender_preference']?.toString().trim();

    final budgetMin = request['budget_min'];

    final budgetMax = request['budget_max'];

    final language = request['language_preference']?.toString().trim() ?? '';

    final note = request['message']?.toString().trim() ?? '';

    final trainer = request['trainers'];

    String trainerName = 'Your trainer';
    String? trainerImage;
    num? trainerPrice;

    if (trainer is Map) {
      final name = trainer['full_name']?.toString().trim();

      final image = trainer['profile_image_url']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        trainerName = name;
      }

      if (image != null && image.isNotEmpty) {
        trainerImage = image;
      }

      trainerPrice = trainer['price_per_session'] as num?;
    }

    final preferenceText = [
      if (preference != null && preference.isNotEmpty)
        '${_capitalize(preference)} preference'
      else
        'No preference',
      if (budgetMin != null && budgetMax != null)
        'AED ${_money(budgetMin)} to ${_money(budgetMax)}',
    ].join(', ');

    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 28),

                  Text(
                    'Your trainer request',
                    style: GSWTextStyles.titleLarge.copyWith(
                      color: GSWColors.textPrimary,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        referenceCode,
                        style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: GSWColors.surfaceInteractive,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Recommendation ready',
                          style: GSWTextStyles.bodyExtraSmall.copyWith(
                            color: GSWColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  _buildRequestCard(
                    goal: goal,
                    days: days,
                    time: time,
                    where: [
                      if (trainingLocation.isNotEmpty) trainingLocation,
                      if (preferredArea.isNotEmpty) preferredArea,
                    ].join(', '),
                    trainer: preferenceText,
                    language: language,
                  ),

                  if (note.isNotEmpty) ...[const SizedBox(height: 24), _buildNoteCard(note)],

                  const SizedBox(height: 24),

                  _buildTrainerCard(
                    trainerName: trainerName,
                    trainerImage: trainerImage,
                    preferredArea: preferredArea,
                    price: trainerPrice,
                  ),
                ],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              GSWButton(
                size: GSWButtonSize.large,
                variant: GSWButtonVariant.primary,
                label: 'Continue',
                onPressed: () async {
                  if (matchOutcome == 'no_fit') {
                    context.push(GSWRoutes.matchNoFit, extra: requestId);
                    return;
                  }

                  final rematchRequested = await context.push<bool>(
                    GSWRoutes.matchedTrainer,
                    extra: requestId,
                  );

                  if (!mounted) return;

                  if (rematchRequested == true) {
                    context.pop(true);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _cancelMatchedRequest,

                child: Text(
                  'Cancel this request',
                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => context.pop(),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GSWColors.borderSecondary),
        ),
        child: const Icon(Icons.chevron_left, color: GSWColors.primary, size: 32),
      ),
    );
  }

  Future<void> _cancelMatchedRequest() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: GSWColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: GSWColors.neutral700,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Cancel this request?',
                    style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'This will remove the recommendation and close this request. '
                    'You can start a new request afterwards.',
                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),

                  const SizedBox(height: 20),

                  GSWButton(
                    size: GSWButtonSize.large,
                    variant: GSWButtonVariant.primary,
                    label: 'Cancel request',
                    onPressed: () {
                      Navigator.of(sheetContext).pop(true);
                    },
                  ),

                  const SizedBox(height: 12),

                  GSWButton(
                    size: GSWButtonSize.large,
                    variant: GSWButtonVariant.tertiary,
                    label: 'Keep request',
                    onPressed: () {
                      Navigator.of(sheetContext).pop(false);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Authentication required.');
      }

      await Supabase.instance.client
          .from('booking_requests')
          .update({'status': 'cancelled'})
          .eq('id', widget.requestId)
          .eq('user_id', user.id)
          .eq('request_type', 'concierge_match');

      if (!mounted) return;

      context.pop(true);
    } catch (error) {
      debugPrint('Cancel matched concierge request failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not cancel the request. Please try again.')),
      );
    }
  }

  Widget _buildRequestCard({
    required String goal,
    required String days,
    required String time,
    required String where,
    required String trainer,
    required String language,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you asked for',
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: GSWColors.neutral700),
          const SizedBox(height: 10),

          _buildDetailRow('Goal', goal),
          _buildDetailRow('Days', days),
          _buildDetailRow('Time', time),
          _buildDetailRow('Where', where),
          _buildDetailRow('Trainer', trainer),
          _buildDetailRow('Language', language, bottomSpacing: 0),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {double bottomSpacing = 14}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your note',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerCard({
    required String trainerName,
    required String? trainerImage,
    required String preferredArea,
    required num? price,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GSWColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WE PICKED YOUR TRAINER',
            style: GSWTextStyles.bodyExtraSmall.copyWith(
              color: GSWColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _buildTrainerAvatar(trainerName, trainerImage),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainerName,
                      style: GSWTextStyles.titleSmall.copyWith(
                        color: GSWColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Personal training',
                        if (preferredArea.isNotEmpty) preferredArea,
                        if (price != null) 'AED ${_money(price)}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerAvatar(String trainerName, String? imagePath) {
    String? url;

    if (imagePath != null && imagePath.isNotEmpty) {
      url = Supabase.instance.client.storage.from('trainer-images').getPublicUrl(imagePath);
    }

    return ClipOval(
      child: Container(
        width: 52,
        height: 52,
        color: GSWColors.surfaceInteractive,
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, alignment: const Alignment(0, -0.8))
            : Center(
                child: Text(
                  trainerName.isEmpty ? 'T' : trainerName[0].toUpperCase(),
                  style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.primary),
                ),
              ),
      ),
    );
  }

  String _goalHeadline(String? goal) {
    switch (goal?.trim().toLowerCase()) {
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
        return _capitalize(goal ?? '');
    }
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

  String _capitalize(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    return '${trimmed[0].toUpperCase()}'
        '${trimmed.substring(1)}';
  }

  String _money(num value) {
    final number = value.toDouble();

    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }

    return number.toStringAsFixed(2);
  }
}
