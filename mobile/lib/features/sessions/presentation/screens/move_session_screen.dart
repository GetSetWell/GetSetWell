import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/sessions/data/services/sessions_service.dart';
import 'package:mobile/features/sessions/presentation/screens/session_moved_screen.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// GetSetWell support line (contacting GetSetWell, never the trainer).
const String _supportWhatsApp = '971505251393';

/// 10.2 Reschedule, 10.2c Move inside 24 hours, 10.2d Pay to move.
/// Pops `true` when the session was moved.
class MoveSessionScreen extends StatefulWidget {
  const MoveSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<MoveSessionScreen> createState() => _MoveSessionScreenState();
}

class _MoveSessionScreenState extends State<MoveSessionScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  late final SessionsService _service = SessionsService(_client);

  late Future<_MoveData> _dataFuture;

  DateTime? _selectedDay;

  DateTime? _selectedSlot;

  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MoveData> _loadData() async {
    final session = await _service.getSession(widget.sessionId);

    final start = sessionStartDubai(session);
    if (start == null) throw Exception('Session has no scheduled time.');

    final blocked = _blockedReason(session, start);

    final slots = <DateTime>[];
    if (blocked == null) {
      final rows = await _client.rpc(
        'get_reschedule_availability',
        params: {'p_session_id': widget.sessionId},
      );
      if (rows is List) {
        for (final raw in rows) {
          if (raw is! Map) continue;
          final slot = GSWTime.parseToDubai(raw['starts_at']);
          if (slot != null) slots.add(slot);
        }
      }
      slots.sort();
    }

    return _MoveData(session: session, start: start, slots: slots, blocked: blocked);
  }

  _Blocked? _blockedReason(Map<String, dynamic> session, DateTime start) {
    if (!kActiveSessionStatuses.contains(sessionStatus(session))) return _Blocked.notMovable;
    if (!start.isAfter(GSWTime.nowDubai())) return _Blocked.notMovable;
    final count = (session['reschedule_count'] as num?)?.toInt() ?? 0;
    if (count >= 1) return _Blocked.alreadyMoved;
    return null;
  }

  void _reload({bool keepSelection = false}) {
    setState(() {
      if (!keepSelection) {
        _selectedDay = null;
        _selectedSlot = null;
      }
      _dataFuture = _loadData();
    });
  }

  // ---------------------------------------------------------------------------
  // Free move (24 hours or more before)
  // ---------------------------------------------------------------------------

  Future<void> _moveFree(_MoveData data) async {
    final slot = _selectedSlot;
    if (slot == null || _isMoving) return;

    setState(() => _isMoving = true);

    try {
      await _client.rpc(
        'reschedule_session_weekly',
        params: {
          'p_session_id': widget.sessionId,
          'p_new_scheduled_at': GSWTime.dubaiToUtc(
            slot.year,
            slot.month,
            slot.day,
            slot.hour,
            slot.minute,
          ).toIso8601String(),
        },
      );

      if (!mounted) return;
      await _showMoved(data, slot, paidAmount: null);
    } on PostgrestException catch (error) {
      debugPrint('Reschedule failed: ${error.code} ${error.message}');
      if (!mounted) return;
      _handleMoveError(error.message);
    } catch (error) {
      debugPrint('Reschedule failed: $error');
      if (!mounted) return;
      _snack("We couldn't move this session. Please try again.");
    } finally {
      if (mounted) setState(() => _isMoving = false);
    }
  }

  void _handleMoveError(String message) {
    if (message.contains('LATE_MOVE_PAYMENT_REQUIRED')) {
      _snack('Your session is now less than 24 hours away, so moving it follows the late-change rule.');
      _reload(keepSelection: true);
      return;
    }
    if (message.contains('SLOT_UNAVAILABLE') || message.contains('AVAILABILITY_NOT_FOUND')) {
      _snack('That time was just taken. Choose another time.');
      _reload();
      return;
    }
    if (message.contains('SESSION_ALREADY_MOVED')) {
      _reload();
      return;
    }
    if (message.contains('SESSION_NOT_MOVABLE')) {
      _reload();
      return;
    }
    _snack("We couldn't move this session. Please try again.");
  }

  Future<void> _showMoved(_MoveData data, DateTime newStart, {required double? paidAmount}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SessionMovedScreen(
          session: data.session,
          originalStart: data.start,
          newStart: newStart,
          movedAt: GSWTime.nowDubai(),
          paidAmount: paidAmount,
        ),
      ),
    );
    if (!mounted) return;
    context.pop(true);
  }

  // ---------------------------------------------------------------------------
  // Pay to move (inside 24 hours)
  // ---------------------------------------------------------------------------

  Future<void> _openPaySheet(_MoveData data) async {
    final slot = _selectedSlot;
    final amount = data.amounts.halfRate;
    if (slot == null || amount == null || _isMoving) return;

    final moved = await showSessionSheet<bool>(
      context: context,
      builder: (sheetContext) => _PayToMoveSheet(
        trainerFirstName: data.trainer.firstName,
        from: data.start,
        to: slot,
        amount: amount,
        onPay: (method) => _payAndMove(data, slot, amount, method),
        onContactSupport: () => _contactSupport(data),
      ),
    );

    // 10.2e is shown only when the paid move actually went through.
    if (moved == true && mounted) {
      await _showMoved(data, slot, paidAmount: amount);
    }
  }

  /// Charges the late-move amount and then moves the session.
  ///
  /// Returns true only when the session was actually moved. Until Tap is wired
  /// there is no server path for a paid move inside 24 hours, so this returns
  /// false and the sheet shows the "payment not available yet" state. Nothing
  /// is charged and the booking stays as it is.
  Future<bool> _payAndMove(
    _MoveData data,
    DateTime slot,
    double amount,
    PayMethod method,
  ) async {
    // TODO(Tap): charge, then call the paid-move RPC.
    // 1. Create a Tap charge for `amount` (half of sessions.session_rate, no
    //    service fee) with `method`, tied to widget.sessionId and the target slot.
    // 2. After Tap confirms server-side, call the paid-move RPC for
    //    p_session_id / p_new_scheduled_at (UTC via GSWTime.dubaiToUtc).
    // 3. Return true. The sheet closes with `true` and `_openPaySheet` shows
    //    10.2e with the amount paid. Map RPC errors with `_handleMoveError`.
    return false;
  }

  Future<void> _contactSupport(_MoveData data) async {
    final ref = data.referenceCode;
    final message = [
      'Hi GetSetWell, I would like to move my session with ${data.trainer.name} '
          'on ${GSWTime.dayAndTime(data.start)}.',
      if (ref != null) 'Booking $ref.',
    ].join(' ');

    final uri = Uri.https('wa.me', '/$_supportWhatsApp', {'text': message});

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _snack("We couldn't open WhatsApp. Please try again.");
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: FutureBuilder<_MoveData>(
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

            if (data.blocked != null) return _buildBlocked(data);

            _selectedDay ??= _firstSelectableDay(data);

            return _buildContent(data);
          },
        ),
      ),
    );
  }

  Widget _buildContent(_MoveData data) {
    final isLate = data.isLate;
    final day = _selectedDay;
    final daySlots = day == null ? const <DateTime>[] : data.slotsOn(day);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SessionBackButton(
                  onTap: () => context.pop(false),
                  borderColor: GSWColors.surfaceInteractive,
                ),
                const SizedBox(height: 24),
                Text(
                  'Move your session',
                  style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Same trainer, same place. Pick a new day and time.',
                  style: GSWTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    color: GSWColors.textSecondary,
                    height: 22 / 15,
                  ),
                ),
                const SizedBox(height: 24),
                _buildCurrentBooking(data),
                if (isLate) ...[
                  const SizedBox(height: 24),
                  _buildLateNotice(data),
                ],
                const SizedBox(height: 24),
                _label('CHOOSE A DAY'),
                const SizedBox(height: 8),
                _buildDayStrip(data),
                const SizedBox(height: 8),
                _buildDayLegend(data),
                const SizedBox(height: 24),
                _label(day == null ? 'AVAILABLE TIMES' : 'TIMES ON ${GSWTime.dayLong(day).toUpperCase()}'),
                const SizedBox(height: 8),
                if (data.slots.isEmpty)
                  _buildNoTimes('${data.trainer.firstName} has no free times in the next 7 days. Keep your booking, or cancel it under the policy.')
                else if (daySlots.isEmpty)
                  _buildNoTimes('No free times on this day.')
                else
                  _buildTimeGrid(daySlots),
                const SizedBox(height: 24),
                _buildSummary(data),
                if (isLate && data.amounts.halfRate != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'If you cancel instead, you get ${GSWMoney.aed(data.amounts.halfRate)} back.',
                    style: GSWTextStyles.bodySmall.copyWith(
                      color: GSWColors.textSecondary,
                      height: 16 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildBottomBar(data),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GSWTextStyles.bodyExtraSmall.copyWith(
        color: GSWColors.textSecondary,
        fontWeight: FontWeight.w600,
        height: 15 / 11,
      ),
    );
  }

  Widget _buildCurrentBooking(_MoveData data) {
    final location = data.location;
    return Container(
      width: double.infinity,
      // Figma 16 x 12 measured from the outer edge; the 1px border is added by
      // the decoration, so the padding is one less.
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Row(
        children: [
          SessionTrainerAvatar(name: data.trainer.name, imagePath: data.trainer.imagePath, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('CURRENTLY BOOKED'),
                const SizedBox(height: 2),
                Text(
                  '${GSWTime.dayShort(data.start)}, ${GSWTime.timeRange(data.start, kSessionLength)}',
                  style: GSWTextStyles.labelLarge.copyWith(
                    fontSize: 15,
                    color: GSWColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 21 / 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [data.trainer.name, if (location.isNotEmpty) location].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GSWTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    height: 18 / 13,
                    color: GSWColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLateNotice(_MoveData data) {
    final remaining = data.start.difference(GSWTime.nowDubai());
    final hours = remaining.inHours;
    final when = hours >= 1 ? '$hours ${hours == 1 ? 'hour' : 'hours'}' : 'less than an hour';
    final amount = data.amounts.halfRate;

    return Container(
      width: double.infinity,
      // Figma 16 x 14 from the outer edge, minus the 1px border.
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SvgPicture.asset(
              GSWIcons.clock,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(GSWColors.iconPrimary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
                children: [
                  TextSpan(
                    text: 'Your session is in $when. ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: amount == null
                        ? 'Moving it now costs half the session fee. '
                        : 'Moving it now costs ${GSWMoney.aed(amount)}, half the session fee. ',
                  ),
                  TextSpan(text: 'That half goes to ${data.trainer.firstName} for holding the time.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _visibleDays() {
    final now = GSWTime.nowDubai();
    final today = DateTime.utc(now.year, now.month, now.day);
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  DateTime? _firstSelectableDay(_MoveData data) {
    for (final day in _visibleDays()) {
      if (data.slotsOn(day).isNotEmpty) return day;
    }
    return null;
  }

  Widget _buildDayStrip(_MoveData data) {
    final days = _visibleDays();

    return Row(
      children: [
        for (var index = 0; index < days.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(child: _buildDay(data, days[index])),
        ],
      ],
    );
  }

  Widget _buildDay(_MoveData data, DateTime day) {
    final hasSlots = data.slotsOn(day).isNotEmpty;
    final isCurrent = GSWTime.isSameDay(day, data.start);
    final selected = _selectedDay != null && GSWTime.isSameDay(day, _selectedDay!);

    // Figma: unavailable days keep the card fill and border, turn text/tertiary
    // and sit at 50% opacity.
    final bool unavailable = !hasSlots && !isCurrent;
    final Color fill = selected ? GSWColors.primary : GSWColors.surfacePrimary;
    final Color border = selected ? GSWColors.primary : GSWColors.surfaceInteractive;
    final Color top = selected
        ? GSWColors.textInverse
        : unavailable
            ? GSWColors.textTertiary
            : GSWColors.textSecondary;
    final Color main = selected
        ? GSWColors.textInverse
        : unavailable
            ? GSWColors.textTertiary
            : GSWColors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasSlots
          ? () => setState(() {
                _selectedDay = day;
                _selectedSlot = null;
              })
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: unavailable ? 0.5 : 1,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        // 8 + 14 + 2 + 20 + 2 + 5 + 8: the tallest tile (current day with dot).
        height: 59,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(GSWRadius.control),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              GSWTime.weekdayShort(day),
              style: GSWTextStyles.bodyExtraSmall.copyWith(
                color: top,
                fontWeight: FontWeight.w500,
                height: 14 / 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: GSWTextStyles.labelLarge.copyWith(
                color: main,
                fontWeight: FontWeight.w600,
                height: 20 / 16,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected ? GSWColors.textInverse : GSWColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDayLegend(_MoveData data) {
    final unavailable = _visibleDays()
        .where((day) => data.slotsOn(day).isEmpty && !GSWTime.isSameDay(day, data.start))
        .toList();

    final String text;
    if (unavailable.isEmpty) {
      text = 'Your current day.';
    } else if (unavailable.length <= 2) {
      final days = unavailable.map(GSWTime.dayShort).join(' and ');
      text = "Your current day. $days: ${data.trainer.firstName} isn't available.";
    } else {
      text = "Your current day. Grey days: ${data.trainer.firstName} isn't available.";
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 5.5),
          decoration: const BoxDecoration(color: GSWColors.textSecondary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 16 / 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeGrid(List<DateTime> slots) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in slots) SizedBox(width: width, child: _buildTime(slot)),
          ],
        );
      },
    );
  }

  Widget _buildTime(DateTime slot) {
    final selected = _selectedSlot == slot;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedSlot = slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        // 10 + 20 + 2 + 14 + 10.
        height: 56,
        decoration: BoxDecoration(
          color: selected ? GSWColors.primary : GSWColors.surfacePrimary,
          borderRadius: BorderRadius.circular(GSWRadius.control),
          border: Border.all(color: selected ? GSWColors.primary : GSWColors.surfaceInteractive),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              GSWTime.time(slot),
              style: GSWTextStyles.labelLarge.copyWith(
                fontSize: 15,
                color: selected ? GSWColors.textInverse : GSWColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 20 / 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '60 min',
              style: GSWTextStyles.bodyExtraSmall.copyWith(
                color: selected ? GSWColors.textInverse : GSWColors.textSecondary,
                height: 14 / 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTimes(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
      ),
    );
  }

  Widget _buildSummary(_MoveData data) {
    final selected = _selectedSlot;
    final amount = data.amounts.halfRate;
    final cutoff = data.start.subtract(const Duration(hours: 24));

    final String note;
    if (data.isLate) {
      note =
          "No service fee this time. After this, the booking can't be moved again. You can still cancel it, counted from the new time.";
    } else {
      note = amount == null
          ? 'Free to move, once. After ${GSWTime.dayAndTime(cutoff)}, moving costs half the session fee.'
          : 'Free to move, once. After ${GSWTime.dayAndTime(cutoff)}, moving costs ${GSWMoney.aed(amount)}.';
    }

    return Container(
      width: double.infinity,
      // Figma 16 x 12 from the outer edge, minus the 1px border.
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(color: GSWColors.surfaceInteractive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('From', '${GSWTime.dayShort(data.start)}, ${GSWTime.time(data.start)}'),
          const SizedBox(height: 6),
          _summaryRow(
            'To',
            selected == null ? 'Choose a time' : '${GSWTime.dayShort(selected)}, ${GSWTime.time(selected)}',
            accent: selected != null,
          ),
          if (data.isLate) ...[
            const SizedBox(height: 6),
            _summaryRow('To pay now', amount == null ? '–' : 'AED ${amount.toStringAsFixed(2)}'),
          ],
          const SizedBox(height: 6),
          Text(
            note,
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 17 / 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool accent = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GSWTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              height: 18 / 13,
              color: GSWColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GSWTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            height: 18 / 13,
            fontWeight: FontWeight.w600,
            color: accent ? GSWColors.textAccent : GSWColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(_MoveData data) {
    final selected = _selectedSlot;
    final amount = data.amounts.halfRate;

    final String label;
    final VoidCallback? onPressed;

    if (selected == null) {
      label = 'Choose a new time';
      onPressed = null;
    } else if (data.isLate) {
      label = amount == null ? 'Pay and move' : 'Pay ${GSWMoney.aed(amount)} and move';
      onPressed = amount == null ? null : () => _openPaySheet(data);
    } else {
      label = 'Move to ${GSWTime.dayShort(selected)}, ${GSWTime.time(selected)}';
      onPressed = () => _moveFree(data);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GSWButton(label: label, isLoading: _isMoving, onPressed: _isMoving ? null : onPressed),
          const SizedBox(height: 4),
          GSWButton(
            label: 'Keep ${GSWTime.dayShort(data.start)}',
            variant: GSWButtonVariant.tertiary,
            onPressed: _isMoving ? null : () => context.pop(false),
          ),
        ],
      ),
    );
  }

  /// One move per booking (policy 5.5), or a session that has started or
  /// closed: say so clearly instead of showing a picker that cannot work.
  Widget _buildBlocked(_MoveData data) {
    final alreadyMoved = data.blocked == _Blocked.alreadyMoved;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SessionBackButton(
                  onTap: () => context.pop(false),
                  borderColor: GSWColors.surfaceInteractive,
                ),
          const SizedBox(height: 24),
          Text(
            alreadyMoved ? 'This booking has been moved' : "This session can't be moved",
            style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            alreadyMoved
                ? 'Each booking can be moved once, and this one already has been. You can still cancel it under the cancellation policy.'
                : 'It has already started or is no longer booked.',
            style: GSWTextStyles.bodyLarge.copyWith(
              fontSize: 15,
              color: GSWColors.textSecondary,
              height: 22 / 15,
            ),
          ),
          const SizedBox(height: 24),
          _buildCurrentBooking(data),
          const Spacer(),
          GSWButton(label: 'Back to my session', onPressed: () => context.pop(false)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SessionBackButton(
                  onTap: () => context.pop(false),
                  borderColor: GSWColors.surfaceInteractive,
                ),
          const Spacer(),
          Text(
            "We couldn't load available times",
            style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
          ),
          const Spacer(),
          GSWButton(label: 'Try again', onPressed: _reload),
          const SizedBox(height: 4),
          GSWButton(
            label: 'Go back',
            variant: GSWButtonVariant.tertiary,
            onPressed: () => context.pop(false),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 10.2d Pay to move sheet
// =============================================================================

enum PayMethod { card, applePay }

enum _PayStage { choose, paying, unavailable }

class _PayToMoveSheet extends StatefulWidget {
  const _PayToMoveSheet({
    required this.trainerFirstName,
    required this.from,
    required this.to,
    required this.amount,
    required this.onPay,
    required this.onContactSupport,
  });

  final String trainerFirstName;
  final DateTime from;
  final DateTime to;
  final double amount;

  /// Returns true when the session was moved (the caller then shows 10.2e).
  final Future<bool> Function(PayMethod method) onPay;
  final Future<void> Function() onContactSupport;

  @override
  State<_PayToMoveSheet> createState() => _PayToMoveSheetState();
}

class _PayToMoveSheetState extends State<_PayToMoveSheet> {
  PayMethod _method = PayMethod.card;
  _PayStage _stage = _PayStage.choose;

  String get _fixed => 'AED ${widget.amount.toStringAsFixed(2)}';

  Future<void> _pay() async {
    if (_stage == _PayStage.paying) return;
    setState(() => _stage = _PayStage.paying);

    bool moved = false;
    try {
      moved = await widget.onPay(_method);
    } catch (error) {
      debugPrint('Pay to move failed: $error');
    }

    if (!mounted) return;

    if (moved) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _stage = _PayStage.unavailable);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _PayStage.unavailable) return _buildUnavailable();

    return SessionSheetFrame(
      children: [
        SessionSheetHeading('Pay ${GSWMoney.aed(widget.amount)} to move'),
        SessionSheetIntro(
          '${GSWTime.dayShort(widget.from)}, ${GSWTime.time(widget.from)} moves to '
          '${GSWTime.dayShort(widget.to)}, ${GSWTime.time(widget.to)}.',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
          ),
          child: Column(
            children: [
              _row('Half the session fee, kept for ${widget.trainerFirstName}', _fixed),
              const SizedBox(height: 10),
              _row('Service fee', 'AED 0.00'),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
              const SizedBox(height: 10),
              _row('Total', _fixed, total: true),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay with',
              style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textSecondary, height: 1),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _methodTile(PayMethod.card, 'Card')),
                const SizedBox(width: 8),
                Expanded(child: _methodTile(PayMethod.applePay, 'Apple Pay')),
              ],
            ),
          ],
        ),
        GSWButton(
          label: 'Pay $_fixed',
          isLoading: _stage == _PayStage.paying,
          onPressed: _stage == _PayStage.paying ? null : _pay,
        ),
        GSWButton(
          label: 'Not now',
          variant: GSWButtonVariant.tertiary,
          onPressed: _stage == _PayStage.paying ? null : () => Navigator.of(context).pop(),
        ),
        const SessionFootnote(
          'Payments are processed securely by Tap Payments. Your card details never reach GetSetWell.',
          color: GSWColors.textTertiary,
        ),
      ],
    );
  }

  /// 6.1-style state: the move did not happen and nothing was charged.
  Widget _buildUnavailable() {
    return SessionSheetFrame(
      children: [
        const SessionSheetHeading("Payment isn't available yet"),
        SessionSheetIntro(
          'Your session is still on ${GSWTime.dayShort(widget.from)}, ${GSWTime.time(widget.from)} '
          'and nothing was charged. Message us on WhatsApp and we will move it for you.',
        ),
        GSWButton(
          label: 'Message GetSetWell on WhatsApp',
          onPressed: () async {
            await widget.onContactSupport();
            if (mounted) Navigator.of(context).pop();
          },
        ),
        GSWButton(
          label: 'Keep my session',
          variant: GSWButtonVariant.tertiary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Amount rows: Regular 14 / 20; the total is Medium 15 against SemiBold 16.
  Widget _row(String label, String value, {bool total = false}) {
    final labelStyle = total
        ? GSWTextStyles.labelLarge.copyWith(
            fontSize: 15,
            color: GSWColors.textPrimary,
            height: 20 / 15,
          )
        : GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14);
    final valueStyle = total
        ? GSWTextStyles.labelLarge.copyWith(
            color: GSWColors.textPrimary,
            fontWeight: FontWeight.w600,
            height: 20 / 16,
          )
        : GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14);

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 12),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _methodTile(PayMethod method, String label) {
    final selected = _method == method;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _stage == _PayStage.paying ? null : () => setState(() => _method = method),
      child: Container(
        // 14 + 20 + 14.
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GSWColors.surfacePrimary,
          borderRadius: BorderRadius.circular(GSWRadius.control),
          border: Border.all(
            color: selected ? GSWColors.primary : GSWColors.surfaceInteractive,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GSWTextStyles.labelMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
        ),
      ),
    );
  }
}

// =============================================================================
// Data
// =============================================================================

enum _Blocked { alreadyMoved, notMovable }

class _MoveData {
  _MoveData({
    required this.session,
    required this.start,
    required this.slots,
    required this.blocked,
  })  : trainer = SessionTrainerInfo.fromSession(session),
        amounts = SessionAmounts.fromSession(session);

  final Map<String, dynamic> session;
  final DateTime start;

  /// Every offered start time, Dubai wall clock, sorted. Shown as returned by
  /// the server; no client-side spacing filter.
  final List<DateTime> slots;

  final _Blocked? blocked;
  final SessionTrainerInfo trainer;
  final SessionAmounts amounts;

  String get location => session['location_label']?.toString().trim() ?? '';

  String? get referenceCode {
    final request = session['booking_requests'];
    final value = request is Map ? request['reference_code']?.toString().trim() ?? '' : '';
    return value.isEmpty ? null : value;
  }

  /// Inside 24 hours a move follows the late-cancellation rule (Pay to move).
  bool get isLate => start.difference(GSWTime.nowDubai()) < const Duration(hours: 24);

  List<DateTime> slotsOn(DateTime day) =>
      slots.where((slot) => GSWTime.isSameDay(slot, day)).toList();
}
