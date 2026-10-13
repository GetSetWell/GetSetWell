import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showSessionConfirmationFlow({
  required BuildContext context,
  required Map<String, dynamic> session,
  required Future<void> Function(Map<String, dynamic> session) onBookAgain,
  Future<void> Function()? onFinished,
}) async {
  while (context.mounted) {
    if (!context.mounted) return;
    final firstAnswer = await showModalBottomSheet<_AttendanceAnswer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
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
  final experience = await showModalBottomSheet<_ExperienceAnswer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => _ExperienceSheet(session: session),
  );

  if (!context.mounted || experience == null) {
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
          subtitle:
              'Ready for another session with ${_trainerName(session)}? Choose any available day and time.',
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
              'If you’d like another session with ${_trainerName(session)}, choose any available day and time.',
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

    final result = await showModalBottomSheet<_NotHopedResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (context) => const _NotWhatIHopedSheet(),
    );

    if (!context.mounted || result == null) {
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
      builder: (context) => _SessionIssueReportPage(initialCategory: initialCategory),
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
  final trainerName = _trainerName(session);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) {
      return _SessionBottomSheetFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: GSWColors.surfacePrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check_rounded, color: GSWColors.primary, size: 28),
            ),

            const SizedBox(height: 24),

            Text(
              'Report sent',
              style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
            ),

            const SizedBox(height: 12),

            Text(
              'Thanks for telling us what happened with your session with $trainerName.',
              style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary, height: 1.5),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GSWColors.surfacePrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'We’ll review the session and follow up if we need anything else from you.',
                style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary, height: 1.5),
              ),
            ),

            const SizedBox(height: 24),

            GSWButton(
              label: 'Done',
              variant: GSWButtonVariant.primary,
              size: GSWButtonSize.large,
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _submitSessionOutcome(
  BuildContext context,
  Map<String, dynamic> session, {
  required String outcome,
  String? feedbackCategory,
  String? feedbackNote,
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

    if (context.mounted) {
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
  required Future<void> Function(Map<String, dynamic>) onBookAgain,
}) async {
  final shouldBookAgain = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (context) => _RebookSheet(session: session, title: title, subtitle: subtitle),
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

class _AttendanceSheet extends StatelessWidget {
  const _AttendanceSheet({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

    final trainer = session['trainers'];

    final trainerName = trainer is Map
        ? trainer['full_name']?.toString().trim() ?? 'Your trainer'
        : 'Your trainer';

    final local = scheduledAt == null ? null : _toDubai(scheduledAt);

    final sessionLabel = local == null
        ? trainerName
        : '$trainerName, ${_longDate(local)}, ${_timeLabel(local)}';

    return _SessionBottomSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Did your session take place?',
            style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 24),
          Text(
            sessionLabel,
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 28),
          GSWButton(
            label: 'Yes, it took place',
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, _AttendanceAnswer.tookPlace),
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'No, it did not',
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, _AttendanceAnswer.didNotTakePlace),
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'It was cut short',
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, _AttendanceAnswer.cutShort),
          ),
          const SizedBox(height: 24),
          Text(
            'This is what pays your trainer. If we don’t hear from either of you within 24 hours of the end, we treat it as done. You can still tell us about a problem after that.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ExperienceSheet extends StatelessWidget {
  const _ExperienceSheet({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');

    final trainer = session['trainers'];

    final trainerName = trainer is Map
        ? trainer['full_name']?.toString().trim() ?? 'Your trainer'
        : 'Your trainer';

    final local = scheduledAt == null ? null : _toDubai(scheduledAt);

    final sessionLabel = local == null
        ? trainerName
        : '$trainerName, ${_longDate(local)}, ${_timeLabel(local)}';

    return _SessionBottomSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How did it go?',
            style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 24),
          Text(
            sessionLabel,
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 28),
          GSWButton(
            label: 'It went well',
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, _ExperienceAnswer.wentWell),
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'It was fine',
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, _ExperienceAnswer.fine),
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'Not what I hoped',
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, _ExperienceAnswer.notWhatIHoped),
          ),
          const SizedBox(height: 24),
          Text(
            'Optional. This one is for you and for your trainer, and it does not hold up payment.',
            textAlign: TextAlign.center,
            style: GSWTextStyles.bodySmall.copyWith(color: GSWColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NotWhatIHopedSheet extends StatefulWidget {
  const _NotWhatIHopedSheet();

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
    return _SessionBottomSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sorry it wasn’t what you hoped',
            style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
          ),
          const SizedBox(height: 18),
          Text(
            'Tell us what was off and we’ll help.',
            style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: GSWColors.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _options.entries.map((entry) {
                final selected = _selected == entry.key;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selected = entry.key;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      border: entry.key == _options.keys.last
                          ? null
                          : Border(bottom: BorderSide(color: GSWColors.neutral700)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.value,
                            style: GSWTextStyles.bodyLarge.copyWith(
                              color: GSWColors.textPrimary,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? GSWColors.primary : GSWColors.textSecondary,
                              width: selected ? 3 : 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: selected
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: GSWColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          GSWButton(
            label: 'Send',
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
            onPressed: () {
              Navigator.pop(context, _NotHopedResult(category: _selected, reportProblem: false));
            },
          ),
          const SizedBox(height: 16),
          GSWButton(
            label: 'Report a problem with this session',
            variant: GSWButtonVariant.secondary,
            size: GSWButtonSize.large,
            onPressed: () {
              Navigator.pop(context, _NotHopedResult(category: _selected, reportProblem: true));
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Not now',
                style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionIssueReportPage extends StatefulWidget {
  const _SessionIssueReportPage({this.initialCategory});

  final String? initialCategory;

  @override
  State<_SessionIssueReportPage> createState() => _SessionIssueReportPageState();
}

class _SessionIssueReportPageState extends State<_SessionIssueReportPage> {
  final TextEditingController _detailsController = TextEditingController();

  late String _selected;

  static const _options = <String, String>{
    'trainer_no_show': 'He did not turn up',
    'trainer_late': 'He was very late',
    'not_expected': 'The session was not what I expected',
    'uncomfortable': 'I did not feel comfortable',
    'something_else': 'Something else',
  };

  @override
  void initState() {
    super.initState();

    _selected = _options.containsKey(widget.initialCategory)
        ? widget.initialCategory!
        : _options.keys.first;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _circleBackButton(context),
                    const SizedBox(height: 28),
                    Text(
                      'What happened?',
                      style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary),
                    ),
                    const SizedBox(height: 24),
                    for (final entry in _options.entries) ...[
                      _IssueOptionTile(
                        label: entry.value,
                        selected: _selected == entry.key,
                        onTap: () {
                          setState(() {
                            _selected = entry.key;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _detailsController,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 250,
                      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Tell us what happened...',
                        filled: true,
                        fillColor: GSWColors.backgroundPrimary,
                        helperText: 'A real person reads this.',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: GSWColors.borderSecondary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: GSWColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: GSWButton(
                label: 'Send report',
                variant: GSWButtonVariant.primary,
                size: GSWButtonSize.large,
                onPressed: () {
                  Navigator.pop(
                    context,
                    _IssueReportResult(
                      category: _selected,
                      note: _detailsController.text.trim().isEmpty
                          ? null
                          : _detailsController.text.trim(),
                    ),
                  );
                },
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: GSWColors.backgroundPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? GSWColors.primary : GSWColors.borderSecondary),
        ),
        child: Text(label, style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textPrimary)),
      ),
    );
  }
}

class _RebookSheet extends StatelessWidget {
  const _RebookSheet({required this.session, required this.title, required this.subtitle});

  final Map<String, dynamic> session;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final trainer = session['trainers'];

    final trainerName = trainer is Map
        ? trainer['full_name']?.toString().trim() ?? 'Your trainer'
        : 'Your trainer';

    final firstName = trainerName.trim().split(RegExp(r'\s+')).first;

    return _SessionBottomSheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: GSWTextStyles.titleExtraLarge.copyWith(color: GSWColors.textPrimary)),
          const SizedBox(height: 18),
          Text(subtitle, style: GSWTextStyles.bodyLarge.copyWith(color: GSWColors.textSecondary)),
          const SizedBox(height: 24),
          GSWButton(
            label: 'Book $firstName again',
            variant: GSWButtonVariant.primary,
            size: GSWButtonSize.large,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Not now',
                style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionBottomSheetFrame extends StatelessWidget {
  const _SessionBottomSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: GSWColors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: GSWColors.borderSecondary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 26),
            child,
          ],
        ),
      ),
    );
  }
}

DateTime _toDubai(DateTime value) {
  return value.toUtc().add(const Duration(hours: 4));
}

String _timeLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;

  final minute = value.minute.toString().padLeft(2, '0');

  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
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
      '${value.day} '
      '${months[value.month - 1]}';
}

String _trainerName(Map<String, dynamic> session) {
  final trainer = session['trainers'];

  if (trainer is Map) {
    final name = trainer['full_name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }
  }

  return 'your trainer';
}

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

Widget _circleBackButton(BuildContext context) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => Navigator.pop(context),
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: GSWColors.borderSecondary),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.chevron_left_rounded, color: GSWColors.primary, size: 30),
      ),
    ),
  );
}
