import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Figma 4.4 "Nobody fits yet" (node 1012:6597, note 816:6283).
///
/// No trainer matches area, days and budget together. The screen names all
/// three and lets the customer loosen one, which sends the request back to
/// matching through request_concierge_rematch.
class NobodyFitsScreen extends StatefulWidget {
  const NobodyFitsScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<NobodyFitsScreen> createState() => _NobodyFitsScreenState();
}

enum _Loosen { area, times, budget }

class _NobodyFitsScreenState extends State<NobodyFitsScreen> {
  late Future<_NoFitRequest> _future;

  _Loosen? _selected;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_NoFitRequest> _load() async {
    final client = Supabase.instance.client;
    final customerId = await CustomerIdentityService(client: client).getCustomerId();

    final row = await client
        .from('booking_requests')
        .select('''
          id,
          reference_code,
          status,
          goal,
          preferred_days,
          preferred_time,
          preferred_area,
          budget_min,
          budget_max,
          created_at,
          match_outcome,
          training_locations (
            name
          )
        ''')
        .eq('id', widget.requestId)
        .eq('user_id', customerId)
        .eq('request_type', 'concierge_match')
        .maybeSingle();

    if (row == null) {
      throw Exception('Request not found.');
    }

    final request = _NoFitRequest.fromJson(Map<String, dynamic>.from(row));

    if (mounted && _selected == null) {
      final options = request.options;
      if (options.isNotEmpty) {
        setState(() {
          _selected = options.first;
        });
      }
    }

    return request;
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _updateRequest(_NoFitRequest request) async {
    final choice = _selected;

    if (_isSending || choice == null) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.rpc(
        'request_concierge_rematch',
        params: {
          'p_request_id': request.id,
          'p_reason': switch (choice) {
            _Loosen.area => 'area',
            _Loosen.times => 'days_times',
            _Loosen.budget => 'price',
          },
          'p_note': request.noteFor(choice),
        },
      );

      if (!mounted) return;

      context.pushReplacement(GSWRoutes.conciergeRequestStatus, extra: request.id);
    } catch (error) {
      debugPrint('Nobody fits update failed: $error');

      if (!mounted) return;

      setState(() {
        _isSending = false;
        _error = 'We could not update your request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_NoFitRequest>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              debugPrint('Nobody fits load failed: ${snapshot.error}');
              return _buildError();
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We could not load your request',
            style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
          ),
          const SizedBox(height: 10),
          Text(
            'Check your connection and try again.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const Spacer(),
          GSWButton(
            size: GSWButtonSize.large,
            variant: GSWButtonVariant.primary,
            label: 'Try again',
            onPressed: _retry,
          ),
          const SizedBox(height: 8),
          GSWButton(
            size: GSWButtonSize.large,
            variant: GSWButtonVariant.tertiary,
            label: 'Go back',
            onPressed: () => conciergeSafePop(context),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 14),
        ],
      ),
    );
  }

  Widget _buildContent(_NoFitRequest request) {
    final options = request.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    options.length > 1 ? 'Nobody fits all of this yet' : 'Nobody fits this yet',
                    style: GSWTextStyles.titleLarge.copyWith(
                      color: GSWColors.textPrimary,
                      height: 30 / 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    request.summary(hasOptions: options.isNotEmpty),
                    style: GSWTextStyles.bodyMedium.copyWith(
                      color: GSWColors.textSecondary,
                      fontSize: 15,
                      height: 23 / 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRequestCard(request),
                  if (options.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'WHAT WOULD YOU CHANGE?',
                      style: GSWTextStyles.bodyExtraSmall.copyWith(
                        color: GSWColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 15 / 11,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var index = 0; index < options.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _buildOption(request, options[index]),
                    ],
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 34),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (options.isNotEmpty) ...[
                  GSWButton(
                    size: GSWButtonSize.large,
                    variant: GSWButtonVariant.primary,
                    label: 'Update my request',
                    isLoading: _isSending,
                    onPressed: _isSending || _selected == null
                        ? null
                        : () => _updateRequest(request),
                  ),
                  const SizedBox(height: 8),
                ],
                GSWButton(
                  size: GSWButtonSize.large,
                  variant: GSWButtonVariant.tertiary,
                  label: 'Keep it as it is',
                  onPressed: _isSending ? null : () => conciergeSafePop(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(_NoFitRequest request) {
    final meta = [
      if (request.referenceCode.isNotEmpty) request.referenceCode,
      request.sentLabel,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConciergeCopy.goalHeadline(request.goal),
            style: GSWTextStyles.bodyLarge.copyWith(
              color: GSWColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 22 / 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(_NoFitRequest request, _Loosen option) {
    final selected = _selected == option;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSending
            ? null
            : () {
                setState(() {
                  _selected = option;
                  _error = null;
                });
              },
        borderRadius: BorderRadius.circular(GSWRadius.control),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.control),
            border: Border.all(
              color: selected ? GSWColors.borderFocused : GSWColors.surfaceInteractive,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.optionTitle(option),
                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: GSWColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 21 / 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.optionSubtitle(option),
                      style: GSWTextStyles.bodyMedium.copyWith(
                        color: GSWColors.textSecondary,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Radio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? GSWColors.primary : Colors.transparent,
        border: selected ? null : Border.all(color: GSWColors.borderSecondary, width: 1.5),
      ),
    );
  }
}

class _NoFitRequest {
  const _NoFitRequest({
    required this.id,
    required this.referenceCode,
    required this.goal,
    required this.days,
    required this.time,
    required this.area,
    required this.locationName,
    required this.budgetMin,
    required this.budgetMax,
    required this.createdAt,
  });

  factory _NoFitRequest.fromJson(Map<String, dynamic> json) {
    final location = json['training_locations'];

    return _NoFitRequest(
      id: json['id']?.toString().trim() ?? '',
      referenceCode: json['reference_code']?.toString().trim() ?? '',
      goal: json['goal']?.toString().trim() ?? '',
      days: ConciergeCopy.days(json['preferred_days']),
      time: json['preferred_time']?.toString().trim() ?? '',
      area: json['preferred_area']?.toString().trim() ?? '',
      locationName: location is Map ? location['name']?.toString().trim() : null,
      budgetMin: GSWMoney.parse(json['budget_min']),
      budgetMax: GSWMoney.parse(json['budget_max']),
      createdAt: GSWTime.parseToDubai(json['created_at']),
    );
  }

  final String id;
  final String referenceCode;
  final String goal;
  final List<String> days;
  final String time;
  final String area;
  final String? locationName;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? createdAt;

  /// "Sent yesterday, 9:12 AM", "Sent today, 7:00 AM", "Sent Sat 19 Sep, 9:12 AM".
  String get sentLabel {
    final sent = createdAt;
    if (sent == null) return 'Sent recently';

    final now = GSWTime.nowDubai();
    final String day;
    if (GSWTime.isSameDay(sent, now)) {
      day = 'today';
    } else if (GSWTime.isSameDay(sent, now.subtract(const Duration(days: 1)))) {
      day = 'yesterday';
    } else {
      day = GSWTime.dayShort(sent);
    }

    return 'Sent $day, ${GSWTime.time(sent)}';
  }

  String get _schedule =>ConciergeCopy.daysAndTimePhrase(days, time);

  String? get _budget => ConciergeCopy.budgetRange(budgetMin, budgetMax);

  List<_Loosen> get options => [
    if (area.isNotEmpty) _Loosen.area,
    if (days.isNotEmpty || time.isNotEmpty) _Loosen.times,
    if (budgetMax != null) _Loosen.budget,
  ];

  /// "No trainer on GetSetWell is free on weekday mornings in Dubai Marina
  /// within AED 200 to 300. Change one of these and we'll look again."
  String summary({required bool hasOptions}) {
    final parts = <String>[
      if (_schedule.isNotEmpty) 'on $_schedule',
      if (area.isNotEmpty) 'in $area',
      if (_budget != null) 'within $_budget',
    ];

    final first = parts.isEmpty
        ? 'No trainer on GetSetWell fits this request yet.'
        : 'No trainer on GetSetWell is free ${parts.join(' ')}.';

    return hasOptions ? "$first Change one of these and we'll look again." : first;
  }

  String optionTitle(_Loosen option) {
    switch (option) {
      case _Loosen.area:
        return 'Look beyond $area';
      case _Loosen.times:
        return _addTimesTitle;
      case _Loosen.budget:
        return 'Go above ${GSWMoney.aed(budgetMax)}';
    }
  }

  String optionSubtitle(_Loosen option) {
    switch (option) {
      case _Loosen.area:
        return 'Trainers who also cover nearby areas';
      case _Loosen.times:
        final current = ConciergeCopy.timePlural(time);
        return current.isEmpty
            ? 'Keep your days, add more times'
            : 'Keep $current, add more times';
      case _Loosen.budget:
        return 'You see the price before you book';
    }
  }

  String get _addTimesTitle {
    final lowerDays = days.map((day) => day.toLowerCase()).toSet();
    final hasWeekend = lowerDays.contains('saturday') || lowerDays.contains('sunday');
    final t = time.toLowerCase();

    final extras = <String>[
      if (t != 'evening') 'evenings',
      if (!hasWeekend) 'weekends',
    ];

    if (extras.isEmpty) return 'Add more days or times';

    return 'Add ${extras.join(' or ')}';
  }

  /// Saved as the rematch note so the matcher knows what was loosened.
  String noteFor(_Loosen option) {
    switch (option) {
      case _Loosen.area:
        return 'Nobody fits yet: customer is happy to look beyond $area.';
      case _Loosen.times:
        return 'Nobody fits yet: customer is happy to ${_addTimesTitle.toLowerCase()}.';
      case _Loosen.budget:
        return 'Nobody fits yet: customer is happy to go above ${GSWMoney.aed(budgetMax)}.';
    }
  }
}
