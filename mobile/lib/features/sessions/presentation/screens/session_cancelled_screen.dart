import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/booking_request_route_data.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
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
    final session = await SessionsService(_client).getSession(widget.sessionId);
    if (sessionStartDubai(session) == null) throw Exception('Session has no scheduled time.');
    return _CancelledSessionData(session: session);
  }

  @override
  Widget build(BuildContext context) {
    // Reached with go(), so the stack is empty: Android back opens Sessions
    // instead of closing the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(GSWRoutes.sessions);
      },
      child: Scaffold(
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

              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Center(child: _buildIcon()),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'SESSION CANCELLED',

                      textAlign: TextAlign.center,

                      style: GSWTextStyles.displayLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      data.refundAmount == null
                          ? '${data.firstName} has been told. Your refund is being confirmed and goes back to the card you paid with.'
                          : data.refundAmount! <= 0
                              ? '${data.firstName} has been told.'
                              : '${data.firstName} has been told. ${GSWMoney.aed(data.refundAmount)} is on its way back to the card you paid with.',

                      textAlign: TextAlign.center,

                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildCancelledCard(data),

                  const SizedBox(height: 24),

                  Text(
                    'What happens next',

                    style: GSWTextStyles.titleExtraSmall.copyWith(color: GSWColors.textPrimary, height: 1),
                  ),

                  const SizedBox(height: 8),

                  _buildNextStepsCard(data),

                  const SizedBox(height: 24),

                  Text(
                    data.cancelledTimingText,

                    textAlign: TextAlign.center,

                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textTertiary, height: 16 / 12),
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

        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'What was cancelled',

                  style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textSecondary, height: 20 / 16),
                ),
              ),

              if (data.referenceCode.isNotEmpty)
                Text(
                data.referenceCode,

                style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textAccent, height: 20 / 16),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Divider(color: GSWColors.surfaceInteractive, height: 1, thickness: 1),

          const SizedBox(height: 10),

          Text(
            data.trainerName,

            style: GSWTextStyles.titleSmall.copyWith(color: GSWColors.textPrimary, height: 1),
          ),

          const SizedBox(height: 10),

          Text(
            '${GSWTime.dayLong(data.scheduledAtDubai)}, '
            '${GSWTime.timeRange(data.scheduledAtDubai, kSessionLength)}',

            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
          ),

          if (data.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 10),

            Text(
              data.locationLabel,

              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
            ),
          ],

          const SizedBox(height: 10),

          Text(
            data.refundAmount == null
                ? 'Refund being confirmed, ${GSWMoney.aed(data.totalPaid)} paid'
                : '${GSWMoney.aed(data.refundAmount)} refunded of ${GSWMoney.aed(data.totalPaid)} paid',

            style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textAccent, height: 20 / 14),
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

        borderRadius: BorderRadius.circular(GSWRadius.card),
      ),

      child: Column(
        children: [
          _buildBullet('The refund lands in 5 to 10 working days'),

          const SizedBox(height: 8),

          if (data.isLateCancellation)
            _buildBullet(
              'Half the session fee goes to ${data.firstName} for holding the time',
            )
          else
            _buildBullet('Nothing from the session fee goes to ${data.firstName}'),

          const SizedBox(height: 8),

          _buildBullet('Your slot is released for someone else'),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) => SessionBullet(text);

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

          initialTrainingPlace: BookingRequestRouteData.trainingPlaceFromDb(
            data.session['customer_training_place'],
          ),

          initialVenueChoice: BookingRequestRouteData.venueChoiceFromDb(
            data.session['venue_choice'],
          ),

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),

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

          const SizedBox(height: 12),

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

}

class _CancelledSessionData {
  _CancelledSessionData({required this.session})
      : trainer = SessionTrainerInfo.fromSession(session),
        amounts = SessionAmounts.fromSession(session);

  final Map<String, dynamic> session;
  final SessionTrainerInfo trainer;
  final SessionAmounts amounts;

  Map<String, dynamic> get request {
    final value = session['booking_requests'];
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  String get trainerId => session['trainer_id']?.toString().trim() ?? '';

  String get trainerName => trainer.name;

  String get firstName => trainer.firstName;

  String get referenceCode {
    final value = request['reference_code']?.toString().trim();
    return value != null && value.isNotEmpty ? value : '';
  }

  String get locationLabel => session['location_label']?.toString().trim() ?? '';

  DateTime get scheduledAtDubai => sessionStartDubai(session)!;

  DateTime get cancelledAtDubai =>
      GSWTime.parseToDubai(session['cancelled_at']) ?? GSWTime.nowDubai();

  /// What was paid at booking (snapshot), trainer price only for legacy rows.
  double? get totalPaid => amounts.total;

  bool get isLateCancellation =>
      scheduledAtDubai.difference(cancelledAtDubai) < const Duration(hours: 24);

  /// The refund stored by cancel_session. Never recomputed on the device.
  double? get refundAmount => GSWMoney.parse(session['cancellation_refund_amount']);

  String get cancelledTimingText =>
      'Cancelled ${GSWTime.dayLong(cancelledAtDubai)}, ${GSWTime.time(cancelledAtDubai)}, '
      '${isLateCancellation ? 'inside' : 'outside'} the 24 hour window';
}
