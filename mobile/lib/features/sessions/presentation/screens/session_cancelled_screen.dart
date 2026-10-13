import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/trainers/data/repositories/trainer_repository.dart';
import 'package:mobile/features/trainers/domain/models/trainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionCancelledScreen extends StatefulWidget {
  const SessionCancelledScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionCancelledScreen> createState() => _SessionCancelledScreenState();
}

class _SessionCancelledScreenState extends State<SessionCancelledScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  late Future<_CancelledSessionData> _dataFuture;

  @override
  void initState() {
    super.initState();

    _dataFuture = _loadData();
  }

  Future<_CancelledSessionData> _loadData() async {
    final customerId = await CustomerIdentityService(client: _client).getCustomerId();

    final sessionRow = await _client
        .from('sessions')
        .select('''

          id,

          booking_request_id,

          trainer_id,

          scheduled_at,

          location_label,

          goal,

          notes,

          status,

          cancelled_at,

          cancellation_refund_amount,

          trainers(

            id,

            full_name,

            price_per_session

          )

        ''')
        .eq('id', widget.sessionId)
        .eq('user_id', customerId)
        .single();

    final session = Map<String, dynamic>.from(sessionRow);

    Map<String, dynamic> request = {};

    final requestId = session['booking_request_id']?.toString().trim() ?? '';

    if (requestId.isNotEmpty) {
      final requestRow = await _client
          .from('booking_requests')
          .select('id, reference_code, created_at, goal, message')
          .eq('id', requestId)
          .eq('user_id', customerId)
          .maybeSingle();

      if (requestRow != null) {
        request = Map<String, dynamic>.from(requestRow);
      }
    }

    final trainerRaw = session['trainers'];

    final trainer = trainerRaw is Map ? Map<String, dynamic>.from(trainerRaw) : <String, dynamic>{};

    return _CancelledSessionData(session: session, request: request, trainer: trainer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        child: FutureBuilder<_CancelledSessionData>(
          future: _dataFuture,

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorState();
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(_CancelledSessionData data) {
    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),

            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Center(child: _buildIcon()),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'Session cancelled',

                      textAlign: TextAlign.center,

                      style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      '${data.firstName} has been told & '
                      '${_money(data.refundAmount)} is on its way back to the card you paid with.',

                      textAlign: TextAlign.center,

                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildCancelledCard(data),

                  const SizedBox(height: 24),

                  Text(
                    'What happens next',

                    style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary),
                  ),

                  const SizedBox(height: 8),

                  _buildNextStepsCard(data),

                  const SizedBox(height: 24),

                  Text(
                    data.cancelledTimingText,

                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),

        _buildBottomActions(data),
      ],
    );
  }

  Widget _buildIcon() {
    return Column(
      children: [
        SvgPicture.asset(
          GSWIcons.chatCheck,

          width: 96,

          height: 96,

          colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
        ),
      ],
    );
  }

  Widget _buildCancelledCard(_CancelledSessionData data) {
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

          Divider(color: GSWColors.neutral700, height: 1),

          const SizedBox(height: 10),

          Text(
            data.trainerName,

            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary),
          ),

          const SizedBox(height: 10),

          Text(
            '${_longDate(data.scheduledAtDubai)}, '
            '${_timeLabel(data.scheduledAtDubai)} to '
            '${_timeLabel(data.scheduledAtDubai.add(const Duration(hours: 1)))}',

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),

          if (data.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 10),

            Text(
              data.locationLabel,

              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
            ),
          ],

          const SizedBox(height: 10),

          Text(
            '${_money(data.refundAmount)} refunded of '
            '${_money(data.totalPaid)} paid',

            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard(_CancelledSessionData data) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        children: [
          _buildBullet('The refund lands in 5 to 10 working days'),

          const SizedBox(height: 8),

          if (data.isLateCancellation)
            _buildBullet('Half the session fee goes to ${data.firstName} for holding the time')
          else
            _buildBullet('Nothing from the session fee goes to ${data.firstName}'),

          const SizedBox(height: 8),

          _buildBullet('Your slot is released for someone else'),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),

          child: Container(
            width: 4,

            height: 4,

            decoration: const BoxDecoration(color: GSWColors.primary, shape: BoxShape.circle),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text,

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 1.45),
          ),
        ),
      ],
    );
  }

  Future<void> _bookTrainerAgain(_CancelledSessionData data) async {
    if (data.trainerId.isEmpty) {
      _showRepeatBookingError();

      return;
    }

    try {
      final repository = TrainerRepository(_client);

      final trainers = await repository.getTrainers();

      Trainer? trainer;

      for (final item in trainers) {
        if (item.id == data.trainerId) {
          trainer = item;

          break;
        }
      }

      if (!mounted) return;

      if (trainer == null) {
        _showRepeatBookingError();

        return;
      }

      final sessionGoal = data.session['goal']?.toString().trim();

      final requestGoal = data.request['goal']?.toString().trim();

      final sessionNotes = data.session['notes']?.toString().trim();

      final requestNotes = data.request['message']?.toString().trim();

      context.push(
        GSWRoutes.bookingRequest,

        extra: BookingRequestRouteData(
          trainer: trainer,

          initialGoal: sessionGoal?.isNotEmpty == true ? sessionGoal : requestGoal,

          initialLocationLabel: data.locationLabel,

          initialNotes: sessionNotes?.isNotEmpty == true ? sessionNotes : requestNotes,

          isRepeatBooking: true,
        ),
      );
    } catch (error) {
      debugPrint('Cancelled session repeat booking failed: $error');

      if (!mounted) return;

      _showRepeatBookingError();
    }
  }

  void _showRepeatBookingError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'We could not open this trainer\'s availability. Please try again.',

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
          ),

          backgroundColor: GSWColors.surfaceElevated,

          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildBottomActions(_CancelledSessionData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),

      color: GSWColors.backgroundPrimary,

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          GSWButton(
            size: GSWButtonSize.large,

            variant: GSWButtonVariant.secondary,

            label: 'Book ${data.firstName} again',

            onPressed: () {
              if (data.trainerId.isEmpty) return;

              _bookTrainerAgain(data);
            },
          ),

          const SizedBox(height: 10),

          GSWButton(
            size: GSWButtonSize.large,

            variant: GSWButtonVariant.primary,

            label: 'Back to my sessions',

            onPressed: () {
              context.go(GSWRoutes.sessions);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),

        child: GSWButton(
          size: GSWButtonSize.large,

          variant: GSWButtonVariant.primary,

          label: 'Back to my sessions',

          onPressed: () => context.go(GSWRoutes.sessions),
        ),
      ),
    );
  }

  String _money(double value) {
    final hasDecimals = value != value.roundToDouble();

    return hasDecimals ? 'AED ${value.toStringAsFixed(2)}' : 'AED ${value.toStringAsFixed(0)}';
  }

  String _longDate(DateTime value) {
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

    if (hour == 0) hour = 12;

    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }
}

class _CancelledSessionData {
  const _CancelledSessionData({
    required this.session,

    required this.request,

    required this.trainer,
  });

  final Map<String, dynamic> session;

  final Map<String, dynamic> request;

  final Map<String, dynamic> trainer;

  String get trainerId => session['trainer_id']?.toString().trim() ?? '';

  String get trainerName => trainer['full_name']?.toString().trim().isNotEmpty == true
      ? trainer['full_name'].toString().trim()
      : 'Your trainer';

  String get firstName => trainerName.split(RegExp(r'\s+')).first;

  String get referenceCode {
    final value = request['reference_code']?.toString().trim();

    return value != null && value.isNotEmpty ? value : 'GSW';
  }

  String get locationLabel => session['location_label']?.toString().trim() ?? '';

  DateTime get scheduledAtDubai {
    final parsed = DateTime.parse(session['scheduled_at'].toString());

    return parsed.toUtc().add(const Duration(hours: 4));
  }

  DateTime get cancelledAtDubai {
    final raw = session['cancelled_at']?.toString();

    final parsed = raw != null ? DateTime.tryParse(raw) : null;

    return (parsed ?? DateTime.now()).toUtc().add(const Duration(hours: 4));
  }

  double get sessionRate {
    final raw = trainer['price_per_session'];

    if (raw is num) return raw.toDouble();

    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  double get serviceFee => sessionRate * 0.05;

  double get totalPaid => sessionRate + serviceFee;

  bool get isLateCancellation {
    return scheduledAtDubai.difference(cancelledAtDubai).inMinutes < 24 * 60;
  }

  double get refundAmount {
    final raw = session['cancellation_refund_amount'];

    if (raw is num) return raw.toDouble();

    final parsed = double.tryParse(raw?.toString() ?? '');

    if (parsed != null) return parsed;

    return isLateCancellation ? sessionRate * 0.5 : sessionRate;
  }

  String get cancelledTimingText {
    return 'Cancelled ${_weekday(cancelledAtDubai)} '
        '${cancelledAtDubai.day} ${_month(cancelledAtDubai)}, '
        '${_time(cancelledAtDubai)}, '
        '${isLateCancellation ? 'inside' : 'outside'} '
        'the 24 hour window';
  }

  static String _weekday(DateTime value) {
    const values = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return values[value.weekday - 1];
  }

  static String _month(DateTime value) {
    const values = [
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

    return values[value.month - 1];
  }

  static String _time(DateTime value) {
    var hour = value.hour;

    final period = hour >= 12 ? 'PM' : 'AM';

    hour %= 12;

    if (hour == 0) hour = 12;

    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute $period';
  }
}
