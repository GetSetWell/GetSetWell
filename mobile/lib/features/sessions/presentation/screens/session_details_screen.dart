import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/sessions/presentation/screens/session_confirmation_flow.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionDetailsScreen extends StatefulWidget {
  const SessionDetailsScreen({super.key, required this.sessionId, this.openFeedback = false});

  final String sessionId;

  final bool openFeedback;

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _feedbackPromptScheduled = false;

  late Future<_SessionDetailsData> _sessionFuture;

  final bool _isCancelling = false;

  static const Duration _sessionDuration = Duration(hours: 1);

  static const Duration _freeChangeWindow = Duration(hours: 24);

  @override
  void initState() {
    super.initState();

    _sessionFuture = _loadSession();
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------
  Future<_SessionDetailsData> _loadSession() async {
    final customerId = await CustomerIdentityService(client: _client).getCustomerId();

    if (widget.sessionId.trim().isEmpty) {
      throw Exception('Missing session ID.');
    }

    final sessionRow = await _client
        .from('sessions')
        .select('''
          id,
          booking_request_id,
          trainer_id,
          scheduled_at,
          location_label,
          status,
          customer_training_place,
          venue_choice,
          goal,
          notes,
          completion_prompt_shown_at,
          customer_outcome,
          customer_feedback_category,
          customer_feedback_note,
          customer_confirmed_at,
          trainers(
            id,
            full_name,
            profile_image_url,
            price_per_session
          )
        ''')
        .eq('id', widget.sessionId)
        .eq('user_id', customerId)
        .single();

    final session = Map<String, dynamic>.from(sessionRow);

    final bookingRequestId = session['booking_request_id']?.toString().trim();

    Map<String, dynamic>? request;

    if (bookingRequestId != null && bookingRequestId.isNotEmpty) {
      final requestRow = await _client
          .from('booking_requests')
          .select('''
            id,
            reference_code,
            request_type,
            status,
            goal,
            message,
            trainer_id,
            created_at
          ''')
          .eq('id', bookingRequestId)
          .eq('user_id', customerId)
          .maybeSingle();

      if (requestRow != null) {
        request = Map<String, dynamic>.from(requestRow);
      }
    }

    final trainerId = session['trainer_id']?.toString().trim() ?? '';

    Trainer? trainer;

    if (trainerId.isNotEmpty) {
      final repository = TrainerRepository(_client);

      final trainers = await repository.getTrainers();

      for (final item in trainers) {
        if (item.id == trainerId) {
          trainer = item;

          break;
        }
      }
    }

    final trainerRelationship = session['trainers'];

    final relationshipMap = trainerRelationship is Map
        ? Map<String, dynamic>.from(trainerRelationship)
        : <String, dynamic>{};

    return _SessionDetailsData(
      session: session,

      request: request,

      trainer: trainer,

      trainerRelationship: relationshipMap,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _sessionFuture = _loadSession();
    });

    await _sessionFuture;
  }

  bool _canOpenFeedback(Map<String, dynamic> session) {
    final status = session['status']?.toString().trim().toLowerCase() ?? '';

    if (status != 'confirmed' && status != 'booked') {
      return false;
    }

    final outcome = session['customer_outcome']?.toString().trim() ?? '';

    if (outcome.isNotEmpty) {
      return false;
    }

    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

    if (scheduledAt == null) {
      return false;
    }

    final sessionEnd = scheduledAt.toUtc().add(const Duration(hours: 1));

    final now = DateTime.now().toUtc();

    return !now.isBefore(sessionEnd) && now.isBefore(sessionEnd.add(const Duration(hours: 24)));
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------
  void _goBack() {
    if (context.canPop()) {
      context.pop();

      return;
    }

    context.go(GSWRoutes.sessions);
  }

  void _openTrainer(_SessionDetailsData data) {
    final trainer = data.trainer;

    if (trainer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trainer profile could not be loaded.')));

      return;
    }

    context.push(GSWRoutes.trainerProfile, extra: trainer);
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        child: FutureBuilder<_SessionDetailsData>(
          future: _sessionFuture,

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              debugPrint(
                'Session details load failed: '
                '${snapshot.error}',
              );

              return _buildErrorState();
            }

            final data = snapshot.data!;

            if (widget.openFeedback &&
                !_feedbackPromptScheduled &&
                _canOpenFeedback(data.session)) {
              _feedbackPromptScheduled = true;

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;

                try {
                  await _client.rpc(
                    'mark_session_completion_prompt_shown',

                    params: {'p_session_id': widget.sessionId},
                  );

                  if (!context.mounted) return;

                  await showSessionConfirmationFlow(
                    context: context,

                    session: data.session,

                    onBookAgain: (_) async {
                      if (!mounted) return;

                      context.go(GSWRoutes.sessions);
                    },

                    onFinished: () async {
                      if (!mounted) return;

                      await _reload();
                    },
                  );
                } catch (error) {
                  debugPrint('Feedback notification flow failed: $error');
                }
              });
            }

            return _buildContent(data);
          },
        ),
      ),
    );
  }

  Widget _buildContent(_SessionDetailsData data) {
    final scheduledAt = data.scheduledAt;

    if (scheduledAt == null) {
      return _buildErrorState();
    }

    final end = scheduledAt.add(_sessionDuration);

    final isCancelled = data.isCancelled;

    final isCompleted = data.isCompleted;

    final isUpcoming = scheduledAt.isAfter(_nowDubai());

    final statusLabel = isCancelled
        ? 'Cancelled'
        : isCompleted
        ? 'Completed'
        : 'Confirmed';

    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),

            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _buildBackButton(),

                  const SizedBox(height: 34),

                  Text(
                    'Your session',

                    style: GSWTextStyles.titleLarge.copyWith(
                      color: GSWColors.textPrimary,

                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 12,

                    runSpacing: 8,

                    crossAxisAlignment: WrapCrossAlignment.center,

                    children: [
                      Text(
                        data.referenceCode,

                        style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary),
                      ),

                      _buildStatusPill(statusLabel, highlighted: !isCancelled),
                    ],
                  ),

                  const SizedBox(height: 32),

                  _buildTrainerCard(data),

                  const SizedBox(height: 24),

                  _buildSessionInformation(data, scheduledAt, end),

                  const SizedBox(height: 24),

                  _buildPaymentCard(data),

                  if (isCancelled) ...[const SizedBox(height: 26), _buildCancelledCard(data)],

                  const SizedBox(height: 24),

                  if (!isCancelled && !isCompleted && isUpcoming) _buildInlinePolicyHint(data),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        if (!isCancelled && !isCompleted && isUpcoming) _buildBottomActions(data),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildBackButton() {
    return InkWell(
      onTap: _goBack,

      borderRadius: BorderRadius.circular(999),

      child: Container(
        width: 46,

        height: 46,

        decoration: BoxDecoration(
          shape: BoxShape.circle,

          border: Border.all(color: GSWColors.neutral700),
        ),

        alignment: Alignment.center,

        child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 34),
      ),
    );
  }

  Widget _buildStatusPill(String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

      decoration: BoxDecoration(
        color: highlighted ? GSWColors.surfaceInteractive : GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(999),
      ),

      child: Text(
        label,

        style: GSWTextStyles.labelSmall.copyWith(
          color: highlighted ? GSWColors.textPrimary : GSWColors.textSecondary,

          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRAINER CARD
  // ---------------------------------------------------------------------------
  Widget _buildTrainerCard(_SessionDetailsData data) {
    final imageUrl = data.profileImageUrl;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          _buildTrainerAvatar(data.trainerName, imageUrl),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  data.trainerName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: GSWTextStyles.labelLarge.copyWith(
                    color: GSWColors.textPrimary,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  data.specialty,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          TextButton(
            onPressed: () => _openTrainer(data),

            child: Text(
              'View profile',

              style: GSWTextStyles.bodySmall.copyWith(
                color: GSWColors.primary,

                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerAvatar(String name, String? imageUrl) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,

          width: 48,

          height: 48,

          fit: BoxFit.cover,

          alignment: const Alignment(0, -0.8),

          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarFallback(name);
          },
        ),
      );
    }

    return _buildAvatarFallback(name);
  }

  Widget _buildAvatarFallback(String name) {
    final trimmed = name.trim();

    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return Container(
      width: 48,

      height: 48,

      decoration: const BoxDecoration(color: GSWColors.surfaceInteractive, shape: BoxShape.circle),

      alignment: Alignment.center,

      child: Text(initial, style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary)),
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION INFORMATION
  // ---------------------------------------------------------------------------
  Widget _buildSessionInformation(_SessionDetailsData data, DateTime start, DateTime end) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        children: [
          _detailRow(
            'When',

            '${_dateLabel(start)}, '
                '${_timeLabel(start)} to ${_timeLabel(end)}',
          ),

          const SizedBox(height: 10),

          _detailRow(
            'Where',

            data.locationLabel.isEmpty ? 'Location confirmed with trainer' : data.locationLabel,
          ),

          if (data.goal.isNotEmpty) ...[
            const SizedBox(height: 10),

            _detailRow('Goal', _goalLabel(data.goal)),
          ],

          if (data.note.isNotEmpty) ...[const SizedBox(height: 10), _detailRow('Note', data.note)],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          width: 82,

          child: Text(
            label,

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),

        const SizedBox(width: 10),

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

  // ---------------------------------------------------------------------------
  // PAYMENT
  // ---------------------------------------------------------------------------
  Widget _buildPaymentCard(_SessionDetailsData data) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text('Payment', style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textPrimary)),

          const SizedBox(height: 10),

          _moneyRow('Session, 60 minutes', data.sessionRate),

          const SizedBox(height: 10),

          _moneyRow('Service fee (5%)', data.serviceFee),

          const SizedBox(height: 10),

          Container(width: double.infinity, height: 1, color: GSWColors.neutral700),

          const SizedBox(height: 10),

          _moneyRow('Total paid', data.total, highlighted: true),

          const SizedBox(height: 10),

          Text(
            _paymentSummary(data),

            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
          ),

          const SizedBox(height: 10),

          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,

              minimumSize: Size.zero,

              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),

            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Receipt storage will connect to the payment provider receipt once payments are live.',
                  ),
                ),
              );
            },

            child: Text(
              'View receipt',

              style: GSWTextStyles.bodyMedium.copyWith(
                color: GSWColors.primary,

                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount, {bool highlighted = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
        ),

        const SizedBox(width: 16),

        Text(
          _money(amount),

          style: GSWTextStyles.labelMedium.copyWith(
            color: highlighted ? GSWColors.primary : GSWColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CANCELLED STATE
  // ---------------------------------------------------------------------------
  Widget _buildCancelledCard(_SessionDetailsData data) {
    final calculation = _cancellationCalculation(data);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'What was cancelled',

                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textSecondary),
                ),
              ),

              Text(
                data.referenceCode,

                style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Divider(height: 1, color: GSWColors.neutral700),

          const SizedBox(height: 10),

          Text(
            data.trainerName,

            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 10),

          if (data.scheduledAt != null)
            Text(
              '${_longDateLabel(data.scheduledAt!)}, '
              '${_timeLabel(data.scheduledAt!)} to '
              '${_timeLabel(data.scheduledAt!.add(_sessionDuration))}',

              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
            ),

          const SizedBox(height: 10),

          if (data.locationLabel.isNotEmpty)
            Text(
              data.locationLabel,

              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),

          const SizedBox(height: 10),

          Text(
            '${_money(calculation.refundAmount)} refunded of ${_money(data.total)} paid',

            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.primary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM ACTIONS
  // ---------------------------------------------------------------------------
  Widget _buildBottomActions(_SessionDetailsData data) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),

      color: GSWColors.backgroundPrimary,

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          GSWButton(
            size: GSWButtonSize.large,

            variant: GSWButtonVariant.primary,

            label: 'Move this session',

            onPressed: () async {
              final moved = await context.push<bool>(
                GSWRoutes.moveSession,

                extra: widget.sessionId,
              );

              if (!mounted) return;

              if (moved == true) {
                setState(() {
                  _sessionFuture = _loadSession();
                });
              }
            },
          ),

          const SizedBox(height: 8),

          TextButton(
            onPressed: _isCancelling
                ? null
                : () async {
                    final cancelled = await context.push<bool>(
                      GSWRoutes.cancelSession,

                      extra: widget.sessionId,
                    );

                    if (!mounted) return;

                    if (cancelled == true) {
                      setState(() {
                        _sessionFuture = _loadSession();
                      });
                    }
                  },

            child: _isCancelling
                ? const SizedBox(
                    width: 18,

                    height: 18,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: GSWColors.textSecondary,
                    ),
                  )
                : Text(
                    'Cancel booking',

                    style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlinePolicyHint(_SessionDetailsData data) {
    final calculation = _cancellationCalculation(data);

    return Center(
      child: Text(
        calculation.shortMessage,

        textAlign: TextAlign.center,

        style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.45),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------------
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              'Could not load this session.',

              textAlign: TextAlign.center,

              style: GSWTextStyles.titleMedium.copyWith(color: GSWColors.textPrimary),
            ),

            const SizedBox(height: 8),

            Text(
              'Please try again.',

              textAlign: TextAlign.center,

              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),

            const SizedBox(height: 24),

            GSWButton(
              size: GSWButtonSize.large,

              variant: GSWButtonVariant.primary,

              label: 'Try again',

              onPressed: _reload,
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _goBack,

              child: Text(
                'Go back',

                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CANCELLATION CALCULATION
  // ---------------------------------------------------------------------------
  _CancellationCalculation _cancellationCalculation(_SessionDetailsData data) {
    final scheduledAt = data.scheduledAt;

    if (scheduledAt == null) {
      return const _CancellationCalculation(
        refundAmount: 0,

        description: 'We could not calculate the refund for this booking.',

        shortMessage: '',

        longMessage: '',
      );
    }

    final now = _nowDubai();

    final remaining = scheduledAt.difference(now);

    if (remaining >= _freeChangeWindow) {
      final refund = data.sessionRate;

      return _CancellationCalculation(
        refundAmount: refund,

        description:
            'You are cancelling at least 24 hours before the session. The session rate is returned. The service fee is retained.',

        shortMessage:
            'Cancel before ${_dateLabel(scheduledAt.subtract(_freeChangeWindow))}, ${_timeLabel(scheduledAt.subtract(_freeChangeWindow))} to get the ${_money(data.sessionRate)} session rate back.',

        longMessage:
            'At least 24 hours before the session, the session rate is refundable. The service fee is retained.',
      );
    }

    if (remaining > Duration.zero) {
      final refund = data.sessionRate * 0.5;

      return _CancellationCalculation(
        refundAmount: refund,

        description:
            'You are cancelling less than 24 hours before the session. Half of the session rate is returned. The service fee is retained.',

        shortMessage:
            'This session is less than 24 hours away. Cancelling now returns ${_money(refund)}.',

        longMessage:
            'Inside 24 hours, half of the session rate is refundable. The service fee is retained.',
      );
    }

    return const _CancellationCalculation(
      refundAmount: 0,

      description: 'The scheduled start time has passed.',

      shortMessage: '',

      longMessage: '',
    );
  }

  // ---------------------------------------------------------------------------
  // FORMATTING
  // ---------------------------------------------------------------------------
  DateTime _nowDubai() {
    return DateTime.now().toUtc().add(const Duration(hours: 4));
  }

  DateTime _toDubai(DateTime value) {
    return value.toUtc().add(const Duration(hours: 4));
  }

  String _dateLabel(DateTime value) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[value.weekday - 1]} '
        '${value.day} '
        '${months[value.month - 1]}';
  }

  String _longDateLabel(DateTime value) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

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

    return '${weekdays[value.weekday - 1]} '
        '${value.day} ${months[value.month - 1]}';
  }

  String _timeLabel(DateTime value) {
    var hour = value.hour;

    final period = hour >= 12 ? 'PM' : 'AM';

    hour %= 12;

    if (hour == 0) {
      hour = 12;
    }

    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }

  String _money(double value) {
    return 'AED ${value.toStringAsFixed(2)}';
  }

  String _goalLabel(String value) {
    final normalized = value.trim().replaceAll('_', ' ');

    if (normalized.isEmpty) return '';

    return '${normalized[0].toUpperCase()}'
        '${normalized.substring(1)}';
  }

  String _paymentSummary(_SessionDetailsData data) {
    final paymentMethod = data.paymentMethod.toLowerCase();

    final method = paymentMethod.contains('apple') ? 'Apple Pay' : 'card';

    final createdAt = data.requestCreatedAt;

    if (createdAt == null) {
      return 'Paid by $method';
    }

    final dubai = _toDubai(createdAt);

    return 'Paid ${dubai.day} '
        '${_shortMonth(dubai.month)} '
        'by $method';
  }

  String _shortMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }
}

// =============================================================================
// DATA MODEL
// =============================================================================
class _SessionDetailsData {
  const _SessionDetailsData({
    required this.session,

    required this.request,

    required this.trainer,

    required this.trainerRelationship,
  });

  final Map<String, dynamic> session;

  final Map<String, dynamic>? request;

  final Trainer? trainer;

  final Map<String, dynamic> trainerRelationship;

  String get bookingRequestId => session['booking_request_id']?.toString().trim() ?? '';

  String get referenceCode {
    final value = request?['reference_code']?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }

    return 'Session';
  }

  DateTime? get scheduledAt {
    final raw = session['scheduled_at']?.toString();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) return null;

    return parsed.toUtc().add(const Duration(hours: 4));
  }

  String get locationLabel => session['location_label']?.toString().trim() ?? '';

  String get status => session['status']?.toString().trim().toLowerCase() ?? '';

  bool get isCancelled => status == 'cancelled' || status == 'canceled';

  bool get isCompleted => status == 'completed';

  String get trainerName {
    final fromModel = trainer?.fullName.trim();

    if (fromModel != null && fromModel.isNotEmpty) {
      return fromModel;
    }

    final relationship = trainerRelationship['full_name']?.toString().trim();

    if (relationship != null && relationship.isNotEmpty) {
      return relationship;
    }

    return 'Your trainer';
  }

  String? get profileImageUrl {
    final fromModel = trainer?.profileImageUrl?.trim();

    if (fromModel != null && fromModel.isNotEmpty) {
      return fromModel;
    }

    final relationship = trainerRelationship['profile_image_url']?.toString().trim();

    if (relationship != null && relationship.isNotEmpty) {
      return relationship;
    }

    return null;
  }

  String get specialty {
    final primaryService = trainer?.primaryService?.trim();

    if (primaryService != null && primaryService.isNotEmpty) {
      return primaryService;
    }

    return 'Personal training';
  }

  String get goal => request?['goal']?.toString().trim() ?? '';

  String get note => request?['message']?.toString().trim() ?? '';

  String get requestType => request?['request_type']?.toString().trim() ?? '';

  double get sessionRate {
    final raw = request?['session_rate'];

    if (raw is num) {
      return raw.toDouble();
    }

    final parsed = double.tryParse(raw?.toString() ?? '');

    if (parsed != null) {
      return parsed;
    }

    final trainerRate = trainer?.pricePerSession;

    if (trainerRate != null) {
      return trainerRate.toDouble();
    }

    final relationshipRate = trainerRelationship['price_per_session'];

    if (relationshipRate is num) {
      return relationshipRate.toDouble();
    }

    return double.tryParse(relationshipRate?.toString() ?? '') ?? 0;
  }

  double get serviceFee {
    final raw = request?['service_fee'];

    if (raw is num) {
      return raw.toDouble();
    }

    final parsed = double.tryParse(raw?.toString() ?? '');

    if (parsed != null) {
      return parsed;
    }

    return sessionRate * 0.05;
  }

  double get total {
    final raw = request?['total'];

    if (raw is num) {
      return raw.toDouble();
    }

    final parsed = double.tryParse(raw?.toString() ?? '');

    if (parsed != null) {
      return parsed;
    }

    return sessionRate + serviceFee;
  }

  String get paymentMethod => request?['payment_method']?.toString().trim() ?? 'card';

  DateTime? get requestCreatedAt {
    final raw = request?['created_at']?.toString();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}

// =============================================================================
// CANCELLATION MODEL
// =============================================================================
class _CancellationCalculation {
  const _CancellationCalculation({
    required this.refundAmount,
    required this.description,
    required this.shortMessage,
    required this.longMessage,
  });

  final double refundAmount;
  final String description;
  final String shortMessage;
  final String longMessage;
}
