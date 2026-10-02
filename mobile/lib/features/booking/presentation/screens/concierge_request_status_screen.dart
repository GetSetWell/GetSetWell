import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConciergeRequestStatusScreen extends StatefulWidget {
  const ConciergeRequestStatusScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<ConciergeRequestStatusScreen> createState() => _ConciergeRequestStatusScreenState();
}

class _ConciergeRequestStatusScreenState extends State<ConciergeRequestStatusScreen> {
  late final SupabaseClient _client;
  late Future<_ConciergeRequestData> _requestFuture;

  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _requestFuture = _loadRequest();
  }

  Future<_ConciergeRequestData> _loadRequest() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Authentication required.');
    }

    final row = await _client
        .from('booking_requests')
        .select('''
          id,
          reference_code,
          request_type,
          status,
          goal,
          preferred_days,
          preferred_time,
          preferred_area,
          trainer_gender_preference,
          budget_min,
          budget_max,
          language_preference,
          message,
          created_at,
          training_locations (
            name
          )
        ''')
        .eq('id', widget.requestId)
        .eq('user_id', user.id)
        .eq('request_type', 'concierge_match')
        .maybeSingle();

    if (row == null) {
      throw Exception('Request not found.');
    }

    return _ConciergeRequestData.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> _refresh() async {
    final future = _loadRequest();

    if (mounted) {
      setState(() {
        _requestFuture = future;
      });
    }

    await future;
  }

  Future<void> _cancelRequest(_ConciergeRequestData request) async {
    if (_isCancelling || !request.canCancel) {
      return;
    }

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
                    'We will stop matching this request. '
                    'You can start a new one afterwards.',
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

    setState(() {
      _isCancelling = true;
    });

    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        throw Exception('Authentication required.');
      }

      await _client
          .from('booking_requests')
          .update({'status': 'cancelled'})
          .eq('id', request.id)
          .eq('user_id', user.id)
          .eq('request_type', 'concierge_match');

      if (!mounted) return;

      context.pop(true);
    } catch (error) {
      debugPrint('Cancel concierge request failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not cancel the request. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: FutureBuilder<_ConciergeRequestData>(
          future: _requestFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorState();
            }

            final request = snapshot.data!;

            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackButton(),
                    const SizedBox(height: 28),
                    _buildHeader(request),
                    const SizedBox(height: 24),
                    _buildProgressCard(request),
                    const SizedBox(height: 24),
                    _buildRequestCard(request),
                    if (request.note.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildNoteCard(request.note),
                    ],
                    if (request.canCancel) ...[
                      const SizedBox(height: 32),
                      _buildCancelButton(request),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: _buildBackButton()),
          const Spacer(),
          Text(
            'Could not load this request.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pop(),
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GSWColors.textSecondary),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.chevron_left_rounded, size: 34, color: GSWColors.primary),
        ),
      ),
    );
  }

  Widget _buildHeader(_ConciergeRequestData request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your trainer request',
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              request.referenceCode,
              style: GSWTextStyles.labelSmall.copyWith(
                color: GSWColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: GSWColors.surfaceInteractive,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                request.statusLabel,
                style: GSWTextStyles.bodyExtraSmall.copyWith(
                  color: GSWColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCard(_ConciergeRequestData request) {
    return _surfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Where it's up to",
            style: GSWTextStyles.labelLarge.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _TimelineStep(
            state: _TimelineStepState.complete,
            title: 'Request sent',
            subtitle: _submittedLabel(request.createdAt),
            showTopLine: false,
          ),
          const _TimelineStep(
            state: _TimelineStepState.current,
            title: 'A person is matching you',
            subtitle: 'We read every request ourselves and check who fits and is free.',
          ),
          const _TimelineStep(
            state: _TimelineStepState.pending,
            title: 'Your recommendation',
            subtitle: 'By tomorrow morning, in the app and on WhatsApp.',
            showBottomLine: false,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(_ConciergeRequestData request) {
    return _surfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you asked for',
            style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: GSWColors.borderSecondary),
          const SizedBox(height: 10),
          _DetailRow(label: 'Goal', value: _goalLabel(request.goal)),
          const SizedBox(height: 10),
          _DetailRow(label: 'Days', value: request.daysLabel),
          const SizedBox(height: 10),
          _DetailRow(label: 'Time', value: _capitalize(request.preferredTime)),
          const SizedBox(height: 10),
          _DetailRow(label: 'Where', value: request.whereLabel),
          const SizedBox(height: 10),
          _DetailRow(label: 'Trainer', value: request.trainerAndBudgetLabel),
          const SizedBox(height: 10),
          _DetailRow(label: 'Language', value: request.languageLabel),
        ],
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    return _surfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your note',
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(_ConciergeRequestData request) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isCancelling ? null : () => _cancelRequest(request),
        style: OutlinedButton.styleFrom(
          foregroundColor: GSWColors.textPrimary,
          side: BorderSide(color: GSWColors.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: _isCancelling
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: GSWColors.primary),
              )
            : Text(
                'Cancel this request',
                style: GSWTextStyles.bodyLarge.copyWith(
                  color: GSWColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _surfaceCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  String _goalLabel(String value) {
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
      case 'something else':
        return 'Your training goal';
      default:
        return _capitalize(value);
    }
  }

  String _capitalize(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Not specified';
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  String _submittedLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Recently';
    }

    final dubai = createdAt.toUtc().add(const Duration(hours: 4));
    final nowDubai = DateTime.now().toUtc().add(const Duration(hours: 4));

    final createdDay = DateTime(dubai.year, dubai.month, dubai.day);
    final today = DateTime(nowDubai.year, nowDubai.month, nowDubai.day);

    final difference = today.difference(createdDay).inDays;

    final hour12 = dubai.hour == 0 ? 12 : (dubai.hour > 12 ? dubai.hour - 12 : dubai.hour);
    final minute = dubai.minute.toString().padLeft(2, '0');
    final period = dubai.hour >= 12 ? 'PM' : 'AM';

    final time = '$hour12:$minute $period';

    if (difference == 0) {
      return 'Today at $time';
    }

    if (difference == 1) {
      return 'Yesterday at $time';
    }

    return '${dubai.day}/${dubai.month}/${dubai.year} at $time';
  }
}

class _ConciergeRequestData {
  const _ConciergeRequestData({
    required this.id,
    required this.referenceCode,
    required this.status,
    required this.goal,
    required this.preferredDays,
    required this.preferredTime,
    required this.preferredArea,
    required this.trainingLocation,
    required this.trainerPreference,
    required this.budgetMin,
    required this.budgetMax,
    required this.language,
    required this.note,
    required this.createdAt,
  });

  factory _ConciergeRequestData.fromJson(Map<String, dynamic> json) {
    final location = json['training_locations'];

    String trainingLocation = '';

    if (location is Map) {
      trainingLocation = location['name']?.toString().trim() ?? '';
    }

    final rawDays = json['preferred_days'];

    return _ConciergeRequestData(
      id: json['id']?.toString().trim() ?? '',
      referenceCode: json['reference_code']?.toString().trim() ?? 'Request',
      status: json['status']?.toString().trim().toLowerCase() ?? '',
      goal: json['goal']?.toString().trim() ?? '',
      preferredDays: rawDays is List
          ? rawDays.map((day) => day.toString().trim()).where((day) => day.isNotEmpty).toList()
          : const [],
      preferredTime: json['preferred_time']?.toString().trim() ?? '',
      preferredArea: json['preferred_area']?.toString().trim() ?? '',
      trainingLocation: trainingLocation,
      trainerPreference: json['trainer_gender_preference']?.toString().trim() ?? '',
      budgetMin: _numberFromJson(json['budget_min']),
      budgetMax: _numberFromJson(json['budget_max']),
      language: json['language_preference']?.toString().trim() ?? '',
      note: json['message']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  final String id;
  final String referenceCode;
  final String status;
  final String goal;
  final List<String> preferredDays;
  final String preferredTime;
  final String preferredArea;
  final String trainingLocation;
  final String trainerPreference;
  final num? budgetMin;
  final num? budgetMax;
  final String language;
  final String note;
  final DateTime? createdAt;

  bool get canCancel =>
      status == 'new' ||
      status == 'pending' ||
      status == 'contacted' ||
      status == 'matching' ||
      status == 'in_progress';

  String get statusLabel {
    if (status == 'matched') {
      return 'Recommendation ready';
    }

    if (status == 'confirmed' || status == 'booked') {
      return 'Booked';
    }

    if (status == 'cancelled' || status == 'canceled') {
      return 'Cancelled';
    }

    return 'Matching in progress';
  }

  String get daysLabel {
    if (preferredDays.isEmpty) {
      return 'Not specified';
    }

    return preferredDays.map(_shortDay).join(', ');
  }

  String get whereLabel {
    final values = <String>[
      if (trainingLocation.isNotEmpty) _capitalizeStatic(trainingLocation),
      if (preferredArea.isNotEmpty) preferredArea,
    ];

    return values.isEmpty ? 'Not specified' : values.join(', ');
  }

  String get trainerAndBudgetLabel {
    final preference = trainerPreference.isEmpty
        ? 'No preference'
        : '${_capitalizeStatic(trainerPreference)} preference';

    if (budgetMin == null || budgetMax == null) {
      return preference;
    }

    return '$preference. AED ${_money(budgetMin!)} to ${_money(budgetMax!)}';
  }

  String get languageLabel => language.isEmpty ? 'Not specified' : _capitalizeStatic(language);

  static num? _numberFromJson(dynamic value) {
    if (value is num) {
      return value;
    }

    return num.tryParse(value?.toString() ?? '');
  }

  static String _money(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  static String _shortDay(String value) {
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

  static String _capitalizeStatic(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Not specified';
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }
}

enum _TimelineStepState { complete, current, pending }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.state,
    required this.title,
    required this.subtitle,
    this.showTopLine = true,
    this.showBottomLine = true,
  });

  final _TimelineStepState state;
  final String title;
  final String subtitle;
  final bool showTopLine;
  final bool showBottomLine;

  static const double _railWidth = 28;
  static const double _dotSize = 14;

  // Aligns the dot with the first line of the title.
  static const double _dotTop = 11;

  @override
  Widget build(BuildContext context) {
    final isPending = state == _TimelineStepState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Line from previous dot into this dot.
                if (showTopLine)
                  Positioned(
                    top: 0,
                    bottom: null,
                    left: (_railWidth / 2) - 1,
                    height: _dotTop + (_dotSize / 2),
                    child: Container(width: 2, color: GSWColors.borderSecondary),
                  ),

                // Line from this dot to the next dot.
                if (showBottomLine)
                  Positioned(
                    top: _dotTop + (_dotSize / 2),
                    bottom: 0,
                    left: (_railWidth / 2) - 1,
                    child: Container(width: 2, color: GSWColors.borderSecondary),
                  ),

                Positioned(top: _dotTop, child: _buildDot()),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: isPending ? GSWColors.textSecondary : GSWColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: GSWTextStyles.bodySmall.copyWith(
                      color: GSWColors.textSecondary,
                      // height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    switch (state) {
      case _TimelineStepState.complete:
        return Container(
          width: _dotSize,
          height: _dotSize,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: GSWColors.primary),
        );

      case _TimelineStepState.current:
        return Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GSWColors.surfacePrimary,
            border: Border.all(color: GSWColors.primary, width: 2),
          ),
        );

      case _TimelineStepState.pending:
        return Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GSWColors.surfacePrimary,
            border: Border.all(color: GSWColors.textSecondary, width: 2),
          ),
        );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
