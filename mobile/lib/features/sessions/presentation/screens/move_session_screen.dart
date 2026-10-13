import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/customer_identity_service.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Duration _sessionDuration = Duration(hours: 1);

const Duration _minimumSlotSeparation = Duration(hours: 2);

class MoveSessionScreen extends StatefulWidget {
  const MoveSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<MoveSessionScreen> createState() => _MoveSessionScreenState();
}

class _MoveSessionScreenState extends State<MoveSessionScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  late Future<_MoveSessionData> _dataFuture;

  DateTime? _selectedDay;

  _AvailabilitySlot? _selectedSlot;

  bool _isMoving = false;

  _LatePaymentMethod _paymentMethod = _LatePaymentMethod.card;

  bool _isLateWindow(DateTime scheduledAt) {
    final remaining = scheduledAt.difference(_nowDubai());

    return remaining > Duration.zero && remaining <= const Duration(hours: 24);
  }

  @override
  void initState() {
    super.initState();

    _dataFuture = _loadData();
  }

  Future<_MoveSessionData> _loadData() async {
    final customerId = await CustomerIdentityService(client: _client).getCustomerId();

    if (widget.sessionId.trim().isEmpty) throw Exception('Missing session ID.');

    final sessionRow = await _client
        .from('sessions')
        .select('''

          id,

          booking_request_id,

          trainer_id,

          scheduled_at,

          location_label,

          status,

          reschedule_count,

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

    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

    if (scheduledAt == null) {
      throw Exception('Session has no scheduled time.');
    }

    final trainerId = session['trainer_id']?.toString().trim() ?? '';

    if (trainerId.isEmpty) {
      throw Exception('Session has no trainer.');
    }

    final availabilityRows = await _client.rpc(
      'get_reschedule_availability',

      params: {'p_session_id': widget.sessionId},
    );

    final slots = <_AvailabilitySlot>[];

    if (availabilityRows is List) {
      for (final raw in availabilityRows) {
        if (raw is! Map) continue;

        final row = Map<String, dynamic>.from(raw);

        final startsAt = DateTime.tryParse(row['starts_at']?.toString() ?? '');

        if (startsAt == null) continue;

        slots.add(_AvailabilitySlot(startsAt: _toDubai(startsAt)));
      }
    }

    slots.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final trainerRaw = session['trainers'];

    final trainer = trainerRaw is Map ? Map<String, dynamic>.from(trainerRaw) : <String, dynamic>{};

    return _MoveSessionData(
      session: session,

      trainer: trainer,

      slots: slots,

      scheduledAt: _toDubai(scheduledAt),
    );
  }

  Future<void> _moveSession(_MoveSessionData data) async {
    final slot = _selectedSlot;

    if (slot == null || _isMoving) return;

    setState(() => _isMoving = true);

    try {
      final targetUtc = slot.startsAt.subtract(const Duration(hours: 4)).toUtc();

      await _client.rpc(
        'reschedule_session_weekly',

        params: {
          'p_session_id': widget.sessionId,

          'p_new_scheduled_at': targetUtc.toIso8601String(),
        },
      );

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SessionMovedScreen(
            trainerName: data.trainerName,

            originalAt: data.scheduledAt,

            newAt: slot.startsAt,

            location: data.locationLabel,

            bookingReference: data.bookingReference,

            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );

      if (!mounted) return;

      context.pop(true);
    } on PostgrestException catch (error) {
      debugPrint('Reschedule failed: ${error.code} ${error.message}');

      if (!mounted) return;

      final message = switch (error.message) {
        'SLOT_UNAVAILABLE' => 'That time is no longer available. Choose another time.',

        'SESSION_ALREADY_MOVED' => 'This booking has already been moved once.',

        'SESSION_NOT_MOVABLE' => 'This booking can no longer be moved.',

        'AVAILABILITY_NOT_FOUND' => 'That time is no longer in the trainer’s availability.',

        _ => 'We could not move this session. Please try again.',
      };

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      setState(() {
        _selectedDay = null;

        _selectedSlot = null;

        _dataFuture = _loadData();
      });
    } catch (error) {
      debugPrint('Reschedule failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not move this session. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMoving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,

      body: SafeArea(
        child: FutureBuilder<_MoveSessionData>(
          future: _dataFuture,

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: GSWColors.primary));
            }

            if (snapshot.hasError || snapshot.data == null) {
              debugPrint('Move session load failed: ${snapshot.error}');

              return _buildErrorState();
            }

            final data = snapshot.data!;

            _selectedDay ??= _firstSelectableDay(data);

            return _buildContent(data);
          },
        ),
      ),
    );
  }

  Widget _buildContent(_MoveSessionData data) {
    final selectedDay = _selectedDay;

    final isLate = _isLateWindow(data.scheduledAt);

    final daySlots = selectedDay == null ? <_AvailabilitySlot>[] : data.slotsForDay(selectedDay);

    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),

            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _buildBackButton(),

                  const SizedBox(height: 24),

                  Text(
                    'Move your session',

                    style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    isLate
                        ? 'Same trainer, same place. Choose an available new day and time.'
                        : 'Same trainer, same place. Pick a new day and time.',

                    style: GSWTextStyles.bodyLarge.copyWith(
                      color: GSWColors.textSecondary,

                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildCurrentBookingCard(data),

                  if (isLate) ...[const SizedBox(height: 24), _buildLateChangeNotice(data)],

                  const SizedBox(height: 24),

                  _sectionLabel('CHOOSE A DAY'),

                  const SizedBox(height: 8),

                  _buildDayStrip(data),

                  const SizedBox(height: 8),

                  _buildAvailabilityNote(data),

                  const SizedBox(height: 24),

                  _sectionLabel(
                    selectedDay == null
                        ? 'AVAILABLE TIMES'
                        : 'TIMES ON ${_longUpperDate(selectedDay)}',
                  ),

                  const SizedBox(height: 8),

                  if (selectedDay == null || daySlots.isEmpty)
                    _buildNoTimes()
                  else
                    _buildTimeGrid(daySlots),

                  const SizedBox(height: 24),

                  _buildMoveSummary(data: data, selected: _selectedSlot),
                ],
              ),
            ),
          ),
        ),

        _buildBottomActions(data),
      ],
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => context.pop(),

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

  Widget _buildCurrentBookingCard(_MoveSessionData data) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: GSWColors.surfaceInteractive),
      ),

      child: Row(
        children: [
          _buildTrainerAvatar(data.trainerName, data.profileImageUrl),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'CURRENTLY BOOKED',

                  style: GSWTextStyles.labelExtraSmall.copyWith(
                    color: GSWColors.textSecondary,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '${_dateLabel(data.scheduledAt)}, '
                  '${_timeLabel(data.scheduledAt)} to '
                  '${_timeLabel(data.scheduledAt.add(_sessionDuration))}',

                  style: GSWTextStyles.labelMedium.copyWith(
                    color: GSWColors.textPrimary,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  [
                    data.trainerName,

                    if (data.locationLabel.isNotEmpty) data.locationLabel,
                  ].join(' · '),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLateChangeNotice(_MoveSessionData data) {
    final remaining = data.scheduledAt.difference(_nowDubai());

    final hours = remaining.inHours;

    final timeText = hours >= 1 ? '$hours ${hours == 1 ? 'hour' : 'hours'}' : 'less than an hour';

    final fee = data.lateMoveFee;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: GSWColors.neutral700),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(Icons.access_time_rounded, size: 24, color: GSWColors.textPrimary),

          const SizedBox(width: 12),

          Expanded(
            child: Text.rich(
              TextSpan(
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: GSWColors.textPrimary,

                  height: 1.45,
                ),

                children: [
                  TextSpan(text: 'Your session is in $timeText. '),

                  TextSpan(
                    text: fee == null
                        ? 'Moving it now costs half the session fee. The price is currently unavailable.'
                        : 'Moving it now costs AED ${_money(fee)}, half the session fee. ',

                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  if (fee != null)
                    TextSpan(text: 'That half goes to ${data.firstName} for holding the time.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayStrip(_MoveSessionData data) {
    final dates = _visibleDays();

    return SizedBox(
      height: 70,

      child: ListView.separated(
        scrollDirection: Axis.horizontal,

        physics: const ClampingScrollPhysics(),

        itemCount: dates.length,

        separatorBuilder: (_, _) => const SizedBox(width: 6),

        itemBuilder: (context, index) {
          final day = dates[index];

          final hasSlots = data.slotsForDay(day).isNotEmpty;

          final isCurrentDay = _sameDay(day, data.scheduledAt);

          final isSelected = _selectedDay != null && _sameDay(day, _selectedDay!);

          return InkWell(
            onTap: hasSlots
                ? () {
                    setState(() {
                      _selectedDay = day;

                      _selectedSlot = null;
                    });
                  }
                : null,

            borderRadius: BorderRadius.circular(12),

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),

              width: 47,

              padding: const EdgeInsets.symmetric(vertical: 8),

              decoration: BoxDecoration(
                color: isSelected ? GSWColors.primary : GSWColors.surfacePrimary,

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: isSelected
                      ? GSWColors.primary
                      : hasSlots || isCurrentDay
                      ? GSWColors.neutral700
                      : GSWColors.surfacePrimary,
                ),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    _weekday(day),

                    style: GSWTextStyles.bodyExtraSmall.copyWith(
                      color: isSelected
                          ? GSWColors.backgroundPrimary
                          : hasSlots || isCurrentDay
                          ? GSWColors.textSecondary
                          : GSWColors.neutral700,

                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '${day.day}',

                    style: GSWTextStyles.labelLarge.copyWith(
                      color: isSelected
                          ? GSWColors.backgroundPrimary
                          : hasSlots || isCurrentDay
                          ? GSWColors.textPrimary
                          : GSWColors.neutral700,

                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (isCurrentDay) ...[
                    const SizedBox(height: 2),

                    Container(
                      width: 5,

                      height: 5,

                      decoration: BoxDecoration(
                        color: isSelected ? GSWColors.backgroundPrimary : GSWColors.textSecondary,

                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailabilityNote(_MoveSessionData data) {
    const text = 'The dot marks your current booking day. Grey days have no available times.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          width: 5,

          height: 5,

          margin: const EdgeInsets.only(top: 7),

          decoration: const BoxDecoration(color: GSWColors.textSecondary, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            text,

            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeGrid(List<_AvailabilitySlot> slots) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 20) / 3;

        return Wrap(
          spacing: 8,

          runSpacing: 8,

          children: [
            for (final slot in slots) SizedBox(width: width, child: _buildTimeButton(slot)),
          ],
        );
      },
    );
  }

  Widget _buildTimeButton(_AvailabilitySlot slot) {
    final selected = _selectedSlot?.startsAt == slot.startsAt;

    return InkWell(
      onTap: () {
        setState(() => _selectedSlot = slot);
      },

      borderRadius: BorderRadius.circular(16),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),

        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),

        decoration: BoxDecoration(
          color: selected ? GSWColors.primary : GSWColors.surfacePrimary,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: selected ? GSWColors.primary : GSWColors.neutral700),
        ),

        child: Column(
          children: [
            Text(
              _timeLabel(slot.startsAt),

              style: GSWTextStyles.labelMedium.copyWith(
                color: selected ? GSWColors.backgroundPrimary : GSWColors.textPrimary,

                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              '60 min',

              style: GSWTextStyles.bodyExtraSmall.copyWith(
                color: selected ? GSWColors.backgroundPrimary : GSWColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveSummary({required _MoveSessionData data, required _AvailabilitySlot? selected}) {
    final current = data.scheduledAt;

    final cutoff = current.subtract(const Duration(hours: 24));

    final outside24Hours = _nowDubai().isBefore(cutoff);

    final isLate = _isLateWindow(current);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: GSWColors.surfaceInteractive),
      ),

      child: Column(
        children: [
          _summaryRow('From', '${_dateLabel(current)}, ${_timeLabel(current)}'),

          const SizedBox(height: 6),

          _summaryRow(
            'To',

            selected == null
                ? 'Choose a time'
                : '${_dateLabel(selected.startsAt)}, '
                      '${_timeLabel(selected.startsAt)}',

            highlighted: selected != null,
          ),

          if (isLate) ...[
            const SizedBox(height: 6),

            _summaryRow(
              'To pay now',

              data.lateMoveFee == null ? 'Unavailable' : 'AED ${_money(data.lateMoveFee!)}',
            ),
          ],

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerLeft,

            child: Text(
              outside24Hours
                  ? 'Free to move, once. After ${_dateLabel(cutoff)}, ${_timeLabel(cutoff)}, moving may incur the late-change charge.'
                  : 'No service fee this time. After moving, this booking cannot be moved again.',

              style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          width: 72,

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

            style: GSWTextStyles.labelMedium.copyWith(
              color: highlighted ? GSWColors.primary : GSWColors.textPrimary,

              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(_MoveSessionData data) {
    final selected = _selectedSlot;

    final isLate = _isLateWindow(data.scheduledAt);

    final fee = data.lateMoveFee;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),

      color: GSWColors.backgroundPrimary,

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          GSWButton(
            size: GSWButtonSize.large,

            variant: GSWButtonVariant.primary,

            label: selected == null
                ? 'Choose a new time'
                : isLate
                ? fee == null
                      ? 'Session price unavailable'
                      : 'Pay AED ${_money(fee)} and move'
                : 'Move to ${_dateLabel(selected.startsAt)}, ${_timeLabel(selected.startsAt)}',

            onPressed: selected == null || _isMoving || (isLate && fee == null)
                ? null
                : () {
                    if (isLate) {
                      _openLatePaymentSheet(data, selected);
                    } else {
                      _moveSession(data);
                    }
                  },
          ),

          const SizedBox(height: 8),

          GSWButton(
            size: GSWButtonSize.medium,

            variant: GSWButtonVariant.tertiary,

            label: 'Keep ${_dateLabel(data.scheduledAt)}',

            onPressed: _isMoving ? null : () => context.pop(false),
          ),
        ],
      ),
    );
  }

  String _money(double amount) => amount.toStringAsFixed(2);

  Future<void> _openLatePaymentSheet(_MoveSessionData data, _AvailabilitySlot selected) async {
    final fee = data.lateMoveFee;

    if (fee == null) return;

    _paymentMethod = _LatePaymentMethod.card;

    await showModalBottomSheet<void>(
      context: context,

      isScrollControlled: true,

      useSafeArea: true,

      backgroundColor: GSWColors.backgroundPrimary,

      barrierColor: const Color(0xC7000000),

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),

      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,

            8,

            16,

            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),

          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Center(
                  child: Container(
                    width: 40,

                    height: 4,

                    decoration: BoxDecoration(
                      color: GSWColors.neutral700,

                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Pay AED ${_money(fee)} to move',

                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
                ),

                const SizedBox(height: 18),

                Text(
                  '${_dateLabel(data.scheduledAt)}, ${_timeLabel(data.scheduledAt)} moves to '
                  '${_dateLabel(selected.startsAt)}, ${_timeLabel(selected.startsAt)}.',

                  style: GSWTextStyles.bodyLarge.copyWith(
                    color: GSWColors.textSecondary,

                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 22),

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: GSWColors.surfacePrimary,

                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: Column(
                    children: [
                      _paymentRow(
                        'Half the session fee, kept for ${data.firstName}',

                        'AED ${_money(fee)}',
                      ),

                      const SizedBox(height: 12),

                      _paymentRow('Service fee', 'AED 0.00'),

                      const SizedBox(height: 14),

                      Divider(height: 1, color: GSWColors.neutral700),

                      const SizedBox(height: 14),

                      _paymentRow('Total', 'AED ${_money(fee)}', isTotal: true),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  'Pay with',

                  style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _paymentOption(
                        'Card',

                        selected: _paymentMethod == _LatePaymentMethod.card,

                        onTap: () => setSheetState(() => _paymentMethod = _LatePaymentMethod.card),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: _paymentOption(
                        'Apple Pay',

                        selected: _paymentMethod == _LatePaymentMethod.applePay,

                        onTap: () =>
                            setSheetState(() => _paymentMethod = _LatePaymentMethod.applePay),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                GSWButton(
                  size: GSWButtonSize.large,

                  variant: GSWButtonVariant.primary,

                  label: 'Pay AED ${_money(fee)}',

                  // The Tap payment confirmation/webhook is not implemented.

                  // Do not reschedule or show a paid receipt before server confirmation.
                  onPressed: null,
                ),

                const SizedBox(height: 8),

                GSWButton(
                  size: GSWButtonSize.medium,

                  variant: GSWButtonVariant.tertiary,

                  label: 'Not now',

                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),

                const SizedBox(height: 14),

                Center(
                  child: Text(
                    'Secure payment will be available once checkout is connected.',

                    textAlign: TextAlign.center,

                    style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentRow(String label, String amount, {bool isTotal = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Expanded(
          child: Text(
            label,

            style: (isTotal ? GSWTextStyles.labelMedium : GSWTextStyles.bodyMedium).copyWith(
              color: isTotal ? GSWColors.textPrimary : GSWColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Text(
          amount,

          style: (isTotal ? GSWTextStyles.labelMedium : GSWTextStyles.bodyMedium).copyWith(
            color: GSWColors.textPrimary,

            fontWeight: isTotal ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }

  Widget _paymentOption(String text, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(14),

      child: Container(
        height: 54,

        alignment: Alignment.center,

        decoration: BoxDecoration(
          color: GSWColors.surfacePrimary,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: selected ? GSWColors.primary : GSWColors.neutral700,

            width: selected ? 1.5 : 1,
          ),
        ),

        child: Text(text, style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary)),
      ),
    );
  }

  Widget _buildNoTimes() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Text(
        'No available times on this day.',

        textAlign: TextAlign.center,

        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Text(
              'Could not load available times.',

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

              onPressed: () {
                setState(() {
                  _selectedDay = null;

                  _selectedSlot = null;

                  _dataFuture = _loadData();
                });
              },
            ),

            const SizedBox(height: 8),

            GSWButton(
              size: GSWButtonSize.medium,

              variant: GSWButtonVariant.tertiary,

              label: 'Go back',

              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,

      style: GSWTextStyles.labelExtraSmall.copyWith(
        color: GSWColors.textSecondary,

        fontWeight: FontWeight.w600,
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

  DateTime? _firstSelectableDay(_MoveSessionData data) {
    for (final day in _visibleDays()) {
      if (data.slotsForDay(day).isNotEmpty) {
        return day;
      }
    }

    return null;
  }

  List<DateTime> _visibleDays() {
    final nowDubai = _nowDubai();

    final today = DateTime(nowDubai.year, nowDubai.month, nowDubai.day);

    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _nowDubai() {
    return DateTime.now().toUtc().add(const Duration(hours: 4));
  }

  static DateTime _toDubai(DateTime value) {
    return value.toUtc().add(const Duration(hours: 4));
  }

  String _weekday(DateTime value) {
    const values = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return values[value.weekday - 1];
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
        '${value.day} ${months[value.month - 1]}';
  }

  String _longUpperDate(DateTime value) {
    const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

    const months = [
      'JANUARY',

      'FEBRUARY',

      'MARCH',

      'APRIL',

      'MAY',

      'JUNE',

      'JULY',

      'AUGUST',

      'SEPTEMBER',

      'OCTOBER',

      'NOVEMBER',

      'DECEMBER',
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

class _MoveSessionData {
  const _MoveSessionData({
    required this.session,

    required this.trainer,

    required this.slots,

    required this.scheduledAt,
  });

  final Map<String, dynamic> session;

  final Map<String, dynamic> trainer;

  final List<_AvailabilitySlot> slots;

  final DateTime scheduledAt;

  String get trainerName => trainer['full_name']?.toString().trim().isNotEmpty == true
      ? trainer['full_name'].toString().trim()
      : 'Your trainer';

  String get firstName => trainerName.split(RegExp(r'\s+')).first;

  String? get profileImageUrl {
    final value = trainer['profile_image_url']?.toString().trim();

    return value != null && value.isNotEmpty ? value : null;
  }

  String get locationLabel => session['location_label']?.toString().trim() ?? '';

  String? get bookingReference => null; // No public booking code is included in the session query.

  double? get sessionRate {
    final raw = trainer['price_per_session'];

    final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

    if (value == null || !value.isFinite || value <= 0) return null;

    return value;
  }

  double? get lateMoveFee => sessionRate == null ? null : sessionRate! / 2;

  List<_AvailabilitySlot> slotsForDay(DateTime day) {
    final daySlots = slots.where((slot) {
      return slot.startsAt.year == day.year &&
          slot.startsAt.month == day.month &&
          slot.startsAt.day == day.day;
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (daySlots.isEmpty) {
      return const <_AvailabilitySlot>[];
    }

    final filtered = <_AvailabilitySlot>[];

    for (final slot in daySlots) {
      if (filtered.isEmpty) {
        filtered.add(slot);

        continue;
      }

      final previous = filtered.last;

      if (slot.startsAt.difference(previous.startsAt) >= _minimumSlotSeparation) {
        filtered.add(slot);
      }
    }

    return filtered;
  }
}

enum _LatePaymentMethod { card, applePay }

class _AvailabilitySlot {
  const _AvailabilitySlot({required this.startsAt});

  final DateTime startsAt;
}
