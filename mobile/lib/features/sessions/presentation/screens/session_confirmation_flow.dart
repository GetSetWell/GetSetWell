import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/sessions/presentation/widgets/session_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showSessionConfirmationFlow({
  required BuildContext context,
  required Map<String, dynamic> session,
  required Future<void> Function(Map<String, dynamic> session) onBookAgain,
  Future<void> Function()? onFinished,
}) async {
  while (true) {
    if (!context.mounted) return;

    final firstAnswer = await showSessionSheet<_AttendanceAnswer>(
      context: context,
      builder: (context) => _AttendanceSheet(session: session),
    );

    if (!context.mounted || firstAnswer == null) {
      await onFinished?.call();
      return;
    }

    switch (firstAnswer) {
      case _AttendanceAnswer.tookPlace:
        await _showExperienceSheet(context, session, onBookAgain);

        await onFinished?.call();
        return;

      case _AttendanceAnswer.didNotTakePlace:
        final submitted = await _openIssuePage(context, session, outcome: 'did_not_take_place');

        if (!context.mounted) return;

        if (submitted) {
          await onFinished?.call();
          return;
        }

        // User pressed Back from "What happened?"
        // Show the attendance sheet again.
        continue;

      case _AttendanceAnswer.cutShort:
        final submitted = await _openIssuePage(context, session, outcome: 'cut_short');

        if (!context.mounted) return;

        if (submitted) {
          await onFinished?.call();
          return;
        }

        // User pressed Back.
        continue;
    }
  }
}

Future<void> _showExperienceSheet(
  BuildContext context,
  Map<String, dynamic> session,
  Future<void> Function(Map<String, dynamic>) onBookAgain,
) async {
  final experience = await showSessionSheet<_ExperienceAnswer>(
    context: context,
    builder: (context) => _ExperienceSheet(session: session),
  );

  if (!context.mounted) return;

  // Dismissing "How did it go?" must not lose the "it took place" answer:
  // record it as took_place_fine (the neutral answer) and stop there.
  if (experience == null) {
    await _submitSessionOutcome(context, session, outcome: 'took_place_fine', quiet: true);
    return;
  }

  switch (experience) {
    case _ExperienceAnswer.wentWell:
      if (await _submitSessionOutcome(context, session, outcome: 'took_place_well')) {
        if (!context.mounted) return;

        await _showRebookSheet(
          context,
          session,
          title: 'Glad it went well',
          subtitle: 'Same time next week with ${_trainerFirstName(session)}?',
          primaryIsBookAgain: true,
          onBookAgain: onBookAgain,
        );
      }
      break;

    case _ExperienceAnswer.fine:
      if (await _submitSessionOutcome(context, session, outcome: 'took_place_fine')) {
        if (!context.mounted) return;

        await _showRebookSheet(
          context,
          session,
          title: 'Thanks for telling us',
          subtitle:
              "If you'd like another session with ${_trainerFirstName(session)}, this slot is free next week.",
          primaryIsBookAgain: false,
          onBookAgain: onBookAgain,
        );
      }
      break;

    case _ExperienceAnswer.notWhatIHoped:
      await _showNotWhatIHopedSheet(context, session);
      break;
  }
}

Future<void> _showNotWhatIHopedSheet(BuildContext context, Map<String, dynamic> session) async {
  while (true) {
    if (!context.mounted) return;

    final result = await showSessionSheet<_NotHopedResult>(
      context: context,
      builder: (context) => _NotWhatIHopedSheet(session: session),
    );

    if (!context.mounted) return;

    if (result == null) {
      // "Not now": the session still took place.
      await _submitSessionOutcome(context, session, outcome: 'took_place_fine', quiet: true);
      return;
    }

    if (result.reportProblem) {
      final submitted = await _openIssuePage(
        context,
        session,
        outcome: 'took_place_not_hoped',
        initialCategory: _issueCategoryForFeedback(result.category),
      );

      if (!context.mounted) return;

      if (submitted) {
        return;
      }

      // User pressed back from the report page.
      // Reopen "Not what I hoped".
      continue;
    }

    await _submitSessionOutcome(
      context,
      session,
      outcome: 'took_place_not_hoped',
      feedbackCategory: result.category,
    );

    return;
  }
}

Future<bool> _openIssuePage(
  BuildContext context,
  Map<String, dynamic> session, {
  required String outcome,
  String? initialCategory,
}) async {
  final result = await Navigator.of(context).push<_IssueReportResult>(
    MaterialPageRoute(
      builder: (context) => _SessionIssueReportPage(
        session: session,
        initialCategory: initialCategory,
      ),
    ),
  );

  if (!context.mounted || result == null) {
    return false;
  }

  final submitted = await _submitSessionOutcome(
    context,
    session,
    outcome: outcome,
    feedbackCategory: result.category,
    feedbackNote: result.note,
  );

  if (!context.mounted || !submitted) return false;

  await _showReportSubmittedSheet(context, session);
  return true;
}

Future<void> _showReportSubmittedSheet(BuildContext context, Map<String, dynamic> session) async {
  final trainer = SessionTrainerInfo.fromSession(session);

  await showSessionSheet<void>(
    context: context,
    builder: (context) => SessionSheetFrame(
      children: [
        const SessionSheetHeading('Report sent'),
        SessionSheetIntro(
          'Thanks for telling us about your session with ${trainer.firstName}. '
          'A real person reads every report. We reply the same day if you write before 6:00 PM.',
        ),
        GSWButton(label: 'Done', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

Future<bool> _submitSessionOutcome(
  BuildContext context,
  Map<String, dynamic> session, {
  required String outcome,
  String? feedbackCategory,
  String? feedbackNote,
  bool quiet = false,
}) async {
  final sessionId = session['id']?.toString().trim() ?? '';

  if (sessionId.isEmpty) {
    return false;
  }

  try {
    await Supabase.instance.client.rpc(
      'submit_session_outcome',
      params: {
        'p_session_id': sessionId,
        'p_outcome': outcome,
        'p_feedback_category': feedbackCategory,
        'p_feedback_note': feedbackNote,
      },
    );

    return true;
  } catch (error) {
    debugPrint('Submit session outcome failed: $error');

    if (error.toString().contains('SESSION_OUTCOME_ALREADY_SUBMITTED')) return true;

    if (context.mounted && !quiet) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'We could not save your response. Please try again.',
              style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary),
            ),
            backgroundColor: GSWColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    return false;
  }
}

Future<void> _showRebookSheet(
  BuildContext context,
  Map<String, dynamic> session, {
  required String title,
  required String subtitle,
  required bool primaryIsBookAgain,
  required Future<void> Function(Map<String, dynamic>) onBookAgain,
}) async {
  final shouldBookAgain = await showSessionSheet<bool>(
    context: context,
    builder: (context) => _RebookSheet(
      session: session,
      title: title,
      subtitle: subtitle,
      primaryIsBookAgain: primaryIsBookAgain,
    ),
  );

  if (!context.mounted || shouldBookAgain != true) {
    return;
  }

  await onBookAgain(session);
}

enum _AttendanceAnswer { tookPlace, didNotTakePlace, cutShort }

enum _ExperienceAnswer { wentWell, fine, notWhatIHoped }

class _NotHopedResult {
  const _NotHopedResult({required this.category, required this.reportProblem});

  final String category;
  final bool reportProblem;
}

class _IssueReportResult {
  const _IssueReportResult({required this.category, required this.note});

  final String category;
  final String? note;
}

// =============================================================================
// Sheets (11.1, 11.2, 11.2b to 11.2d) and the report page (11.3)
// =============================================================================

String _sessionLine(Map<String, dynamic> session) {
  final start = sessionStartDubai(session);
  final name = SessionTrainerInfo.fromSession(session).name;
  return start == null ? name : '$name, ${GSWTime.dayLong(start)}, ${GSWTime.time(start)}';
}

class _AttendanceSheet extends StatelessWidget {
  const _AttendanceSheet({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    return SessionSheetFrame(
      children: [
        const SessionSheetHeading('Did your session take place?'),
        SessionSheetIntro(_sessionLine(session)),
        GSWButton(
          label: 'Yes, it took place',
          onPressed: () => Navigator.pop(context, _AttendanceAnswer.tookPlace),
        ),
        GSWButton(
          label: 'No, it did not',
          variant: GSWButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, _AttendanceAnswer.didNotTakePlace),
        ),
        GSWButton(
          label: 'It was cut short',
          variant: GSWButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, _AttendanceAnswer.cutShort),
        ),
        const SessionFootnote(
          "This is what pays your trainer. If we don't hear from either of you within 24 hours of the end, we treat it as done. You can still tell us about a problem after that.",
          color: GSWColors.textTertiary,
        ),
      ],
    );
  }
}

class _ExperienceSheet extends StatelessWidget {
  const _ExperienceSheet({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final trainer = SessionTrainerInfo.fromSession(session);

    return SessionSheetFrame(
      children: [
        const SessionSheetHeading('How did it go?'),
        SessionSheetIntro(_sessionLine(session)),
        GSWButton(
          label: 'It went well',
          onPressed: () => Navigator.pop(context, _ExperienceAnswer.wentWell),
        ),
        GSWButton(
          label: 'It was fine',
          variant: GSWButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, _ExperienceAnswer.fine),
        ),
        GSWButton(
          label: 'Not what I hoped',
          variant: GSWButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, _ExperienceAnswer.notWhatIHoped),
        ),
        SessionFootnote(
          'Optional. This one is for you and for ${trainer.firstName}, and it does not hold up ${trainer.possessive} payment.',
          color: GSWColors.textTertiary,
        ),
      ],
    );
  }
}

class _NotWhatIHopedSheet extends StatefulWidget {
  const _NotWhatIHopedSheet({required this.session});

  final Map<String, dynamic> session;

  @override
  State<_NotWhatIHopedSheet> createState() => _NotWhatIHopedSheetState();
}

class _NotWhatIHopedSheetState extends State<_NotWhatIHopedSheet> {
  String _selected = 'session_itself';

  static const _options = <String, String>{
    'session_itself': 'The session itself',
    'timing_lateness': 'Timing or lateness',
    'place': 'The place',
    'price': 'The price',
    'something_else': 'Something else',
  };

  @override
  Widget build(BuildContext context) {
    final keys = _options.keys.toList();

    return SessionSheetFrame(
      children: [
        const SessionSheetHeading("Sorry it wasn't what you hoped"),
        const SessionSheetIntro("Tell us what was off and we'll help."),
        // Figma "Reasons": 16px side padding, rows 15px top and bottom with a
        // 12px gap, 1px inset dividers, Regular 15 / 22 (Medium when selected).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: GSWColors.surfacePrimary,
            borderRadius: BorderRadius.circular(GSWRadius.card),
          ),
          child: Column(
            children: [
              for (var index = 0; index < keys.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = keys[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _options[keys[index]]!,
                            style: GSWTextStyles.bodyLarge.copyWith(
                              fontSize: 15,
                              color: GSWColors.textPrimary,
                              height: 22 / 15,
                              fontWeight: _selected == keys[index] ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Radio(selected: _selected == keys[index]),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        GSWButton(
          label: 'Send',
          onPressed: () =>
              Navigator.pop(context, _NotHopedResult(category: _selected, reportProblem: false)),
        ),
        GSWButton(
          label: 'Report a problem with this session',
          variant: GSWButtonVariant.secondary,
          onPressed: () =>
              Navigator.pop(context, _NotHopedResult(category: _selected, reportProblem: true)),
        ),
        GSWButton(
          label: 'Not now',
          variant: GSWButtonVariant.tertiary,
          onPressed: () => Navigator.pop(context),
        ),
        const SessionFootnote(
          "If it was cut short or didn't go ahead as booked, report it and we'll look into it.",
          color: GSWColors.textTertiary,
        ),
      ],
    );
  }
}

/// 11.2d radio: 22px, 2px ring in text/secondary, lime ring and dot when on.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? GSWColors.primary : GSWColors.textSecondary,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: GSWColors.primary, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

class _SessionIssueReportPage extends StatefulWidget {
  const _SessionIssueReportPage({required this.session, this.initialCategory});

  final Map<String, dynamic> session;
  final String? initialCategory;

  @override
  State<_SessionIssueReportPage> createState() => _SessionIssueReportPageState();
}

class _SessionIssueReportPageState extends State<_SessionIssueReportPage> {
  final TextEditingController _detailsController = TextEditingController();

  late String _selected;

  static const _keys = [
    'trainer_no_show',
    'trainer_late',
    'not_expected',
    'uncomfortable',
    'something_else',
  ];

  late final SessionTrainerInfo _trainer = SessionTrainerInfo.fromSession(widget.session);

  /// Labels use the trainer's first name, never an assumed pronoun.
  String _label(String key) {
    final name = _trainer.firstName;
    switch (key) {
      case 'trainer_no_show':
        return '$name did not turn up';
      case 'trainer_late':
        return '$name was very late';
      case 'not_expected':
        return 'The session was not what I expected';
      case 'uncomfortable':
        return 'I did not feel comfortable';
      default:
        return 'Something else';
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = _keys.contains(widget.initialCategory) ? widget.initialCategory! : _keys.first;
    _detailsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amounts = SessionAmounts.fromSession(widget.session);
    final name = _trainer.firstName;
    final subject = _trainer.subject;

    final totalText = amounts.total == null ? 'a full refund' : 'the full ${GSWMoney.aed(amounts.total)} back';

    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SessionBackButton(onTap: () => Navigator.pop(context)),
                    const SizedBox(height: 24),
                    Text(
                      'What happened?',
                      style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
                    ),
                    const SizedBox(height: 24),
                    for (var index = 0; index < _keys.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      _IssueOptionTile(
                        label: _label(_keys[index]),
                        selected: _selected == _keys[index],
                        onTap: () => setState(() => _selected = _keys[index]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Figma "Text Area Small": min 80 high, 16 x 12 padding,
                    // border/secondary, radius 12, Regular 16.
                    TextField(
                      controller: _detailsController,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 250,
                      style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textPrimary),
                      buildCounter: (
                        BuildContext context, {
                        required int currentLength,
                        required int? maxLength,
                        required bool isFocused,
                      }) =>
                          null,
                      decoration: InputDecoration(
                        hintText: 'Tell us what happened...',
                        hintStyle: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: const BoxConstraints(minHeight: 80),
                        filled: true,
                        fillColor: GSWColors.backgroundPrimary,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GSWRadius.control),
                          borderSide: const BorderSide(color: GSWColors.borderSecondary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GSWRadius.control),
                          borderSide: const BorderSide(color: GSWColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'A real person reads this.',
                            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 16 / 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_detailsController.text.length}/250',
                          style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 16 / 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GSWButton(
                    label: 'Send report',
                    onPressed: () {
                      final note = _detailsController.text.trim();
                      Navigator.pop(
                        context,
                        _IssueReportResult(category: _selected, note: note.isEmpty ? null : note),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Policy v1.2: a trainer no-show gets a full refund, a reschedule, or a
                  // priority rematch with GetSetWell covering up to AED 75 more.
                  SessionFootnote(
                    'We reply the same day if you write before 6:00 PM, and we check with $name, '
                    "who has 12 hours to respond. If $subject didn't turn up, you choose: $totalText, "
                    'a new time with ${_trainer.object}, or another trainer, with us covering up to '
                    'AED 75 of any price difference.',
                    color: GSWColors.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueOptionTile extends StatelessWidget {
  const _IssueOptionTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Figma 11.3 option: 52 high, 16px sides, 12px gap, an 18px ring (lime
    // when selected, surface/interactive otherwise), Regular 15 / 20.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GSWRadius.control),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: GSWColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(GSWRadius.control),
          border: Border.all(color: selected ? GSWColors.primary : GSWColors.surfaceInteractive),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? GSWColors.primary : GSWColors.surfaceInteractive,
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  label,
                  style: GSWTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    color: selected ? GSWColors.textPrimary : GSWColors.textSecondary,
                    height: 20 / 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 11.2b "Glad it went well" and 11.2c "Thanks for telling us".
///
/// The design offers the same slot next week. Availability is confirmed on the
/// next screen, so both choices open the booking flow with this trainer, where
/// the person picks (or keeps) the time and pays on confirm.
class _RebookSheet extends StatelessWidget {
  const _RebookSheet({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.primaryIsBookAgain,
  });

  final Map<String, dynamic> session;
  final String title;
  final String subtitle;

  /// True for "went well" (lime primary), false for "fine" (both secondary).
  final bool primaryIsBookAgain;

  @override
  Widget build(BuildContext context) {
    final trainer = SessionTrainerInfo.fromSession(session);
    final amounts = SessionAmounts.fromSession(session);
    final start = sessionStartDubai(session);
    final nextWeek = start?.add(const Duration(days: 7));
    final location = session['location_label']?.toString().trim() ?? '';

    return SessionSheetFrame(
      children: [
        SessionSheetHeading(title),
        SessionSheetIntro(subtitle),
        if (nextWeek != null)
          Container(
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
                    SessionTrainerAvatar(name: trainer.name, imagePath: trainer.imagePath),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${trainer.name} · ${trainer.serviceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 20 / 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${GSWTime.dayLong(nextWeek)}, ${GSWTime.timeRange(nextWeek, kSessionLength)}',
                  style: GSWTextStyles.labelLarge.copyWith(
                    color: GSWColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 22 / 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [if (location.isNotEmpty) location, '60 min'].join(' · '),
                  style: GSWTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    height: 18 / 13,
                    color: GSWColors.textSecondary,
                  ),
                ),
                if (amounts.sessionRate != null) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, color: GSWColors.surfaceInteractive),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${GSWMoney.aed(amounts.sessionRate)} + ${GSWMoney.aed(GSWMoney.serviceFee(amounts.sessionRate!))} service fee',
                          style: GSWTextStyles.bodyMedium.copyWith(
                            fontSize: 13,
                            height: 18 / 13,
                            color: GSWColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        GSWMoney.aed(GSWMoney.totalWithFee(amounts.sessionRate!)),
                        style: GSWTextStyles.labelLarge.copyWith(
                          color: GSWColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 22 / 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        GSWButton(
          label: 'Book the same time next week',
          variant: primaryIsBookAgain ? GSWButtonVariant.primary : GSWButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, true),
        ),
        GSWButton(
          label: 'Pick another time',
          variant: GSWButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, true),
        ),
        GSWButton(
          label: 'Not now',
          variant: GSWButtonVariant.tertiary,
          onPressed: () => Navigator.pop(context, false),
        ),
        const SessionFootnote(
          'You pay when you confirm on the next screen.',
          color: GSWColors.textTertiary,
        ),
      ],
    );
  }
}

String _trainerFirstName(Map<String, dynamic> session) =>
    SessionTrainerInfo.fromSession(session).firstName;

String _issueCategoryForFeedback(String category) {
  switch (category) {
    case 'timing_lateness':
      return 'trainer_late';
    case 'session_itself':
      return 'not_expected';
    default:
      return 'something_else';
  }
}
