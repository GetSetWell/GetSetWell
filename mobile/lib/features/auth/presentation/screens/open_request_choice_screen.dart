import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:mobile/core/widgets/buttons/gsw_button.dart';
import 'package:mobile/features/booking/domain/models/active_concierge_match.dart';
import 'package:mobile/features/matching/presentation/widgets/concierge_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/auth_sheet.dart';

enum OpenRequestChoice {
  /// 3.6 primary: open the existing request.
  seeRequest,

  /// 3.6 tertiary: go Home.
  goHome,

  /// 3.7 primary: close the open request and send the new answers.
  sendNew,

  /// 3.7 secondary: keep the open request, drop the new answers.
  keepOpen,
}

/// 3.6 Welcome back, same goal and 3.7 Welcome back, different goal.
///
/// Shown straight after the code is verified when the person already has an
/// open Help me choose request. Full screen, never a sheet over the code
/// screen (Figma notes 1002:3201, 1002:3296).
class OpenRequestChoiceScreen extends StatefulWidget {
  const OpenRequestChoiceScreen({
    super.key,
    required this.activeMatch,
    required this.newGoal,
    this.firstName,
    this.addedNote,
  });

  final ActiveConciergeMatch activeMatch;

  /// Goal from the Help me choose answers just given.
  final String newGoal;

  final String? firstName;

  /// The note from the answers just given, already appended to the open
  /// request on the server (3.6 "We added your new note to it"). Null when
  /// there was no note or it could not be saved.
  final String? addedNote;

  /// Same goal (ignoring case and spacing) means 3.6, otherwise 3.7.
  bool get isSameGoal {
    String normalise(String? value) =>
        (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    return normalise(activeMatch.goal) == normalise(newGoal);
  }

  @override
  State<OpenRequestChoiceScreen> createState() => _OpenRequestChoiceScreenState();
}

class _OpenRequestChoiceScreenState extends State<OpenRequestChoiceScreen> {
  String? _area;
  String? _timing;

  @override
  void initState() {
    super.initState();

    _loadDetails();
  }

  /// Area and timing for the meta line. The card renders without them.
  Future<void> _loadDetails() async {
    if (widget.activeMatch.id.isEmpty) return;

    try {
      final row = await Supabase.instance.client
          .from('booking_requests')
          .select('preferred_area, preferred_time, preferred_days')
          .eq('id', widget.activeMatch.id)
          .maybeSingle();

      if (!mounted || row == null) return;

      final area = row['preferred_area']?.toString().trim() ?? '';
      final time = row['preferred_time']?.toString().trim().toLowerCase() ?? '';
      final rawDays = row['preferred_days'];
      final days = rawDays is List
          ? rawDays.map((day) => day.toString().trim().toLowerCase()).toList()
          : <String>[];

      setState(() {
        _area = area.isEmpty ? null : area;
        _timing = _timingLabel(time, days);
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Open request details failed to load: $error');
      }
    }
  }

  String? _timingLabel(String time, List<String> days) {
    const parts = {'morning': 'mornings', 'afternoon': 'afternoons', 'evening': 'evenings'};

    final part = parts[time];

    if (part == null) return null;

    final weekendOnly =
        days.isNotEmpty &&
        days.every((day) => const {'sat', 'saturday', 'sun', 'sunday'}.contains(day));

    return '${weekendOnly ? 'weekend' : 'weekday'} $part';
  }

  bool get _sentToday {
    final created = widget.activeMatch.createdAt;

    if (created == null) return false;

    return GSWTime.isSameDay(GSWTime.toDubai(created), GSWTime.nowDubai());
  }

  String? get _sentLabel {
    final created = widget.activeMatch.createdAt;

    if (created == null) return null;

    final dubai = GSWTime.toDubai(created);

    final now = GSWTime.nowDubai();

    final String day;

    if (GSWTime.isSameDay(dubai, now)) {
      day = 'today';
    } else if (GSWTime.isSameDay(dubai, now.subtract(const Duration(days: 1)))) {
      day = 'yesterday';
    } else {
      day = GSWTime.dayShort(dubai);
    }

    return 'Sent $day, ${GSWTime.time(dubai)}';
  }

  String get _openMeta {
    final parts = <String>[widget.activeMatch.referenceCode];

    final sent = _sentLabel;

    if (sent != null) parts.add(sent);

    if (widget.isSameGoal) {
      final place = <String?>[_area, _timing].nonNulls.join(', ');

      if (place.isNotEmpty) parts.add(place);
    }

    return parts.join(' · ');
  }

  String get _title {
    final name = widget.firstName?.trim() ?? '';

    return name.isEmpty ? 'Welcome back' : 'Welcome back, $name';
  }

  String get _intro {
    if (!widget.isSameGoal) {
      return 'You already have a request open. We work on one at a time so each one '
          'gets proper attention.';
    }

    if (widget.activeMatch.isMatched) {
      return 'You already asked us about this, and your match is ready to see.';
    }

    return _sentToday
        ? "You already asked us about this today, and we're on it. "
              "You'll hear by tomorrow morning."
        : "You already asked us about this, and we're on it. "
              "You'll hear by tomorrow morning.";
  }

  String _goalLabel(String? goal) {
    final headline = ConciergeCopy.goalHeadline(goal);

    return headline.isEmpty ? 'Your trainer match' : headline;
  }

  void _choose(OpenRequestChoice choice) {
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    // System back means "keep what I have": Go to Home on 3.6, keep the open
    // request on 3.7. Either way the caller always gets an answer.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        _choose(widget.isSameGoal ? OpenRequestChoice.goHome : OpenRequestChoice.keepOpen);
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: GSWColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title,
                      style: GSWTextStyles.titleLarge.copyWith(
                        color: GSWColors.textPrimary,
                        height: 30 / 24,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _intro,
                      style: GSWTextStyles.bodyLarge.copyWith(
                        fontSize: 15,
                        height: 23 / 15,
                        color: GSWColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _RequestCard(
                      label: widget.isSameGoal ? 'YOUR OPEN REQUEST' : 'OPEN',
                      chip: AuthStatusChip(
                        label: ConciergeStatus.label(widget.activeMatch.status),
                        fontSize: 12,
                      ),
                      title: _goalLabel(widget.activeMatch.goal),
                      meta: _openMeta,
                    ),

                    if (widget.isSameGoal && (widget.addedNote?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 24),
                      _NoteAddedRow(note: widget.addedNote!.trim()),
                    ],

                    if (!widget.isSameGoal) ...[
                      const SizedBox(height: 12),

                      _RequestCard(
                        label: 'JUST NOW',
                        chip: const AuthStatusChip(
                          label: 'Not sent yet',
                          fontSize: 12,
                          outlined: true,
                        ),
                        title: _goalLabel(widget.newGoal),
                        meta: 'The answers you gave a moment ago',
                        highlighted: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.isSameGoal ? _sameGoalActions() : _differentGoalActions(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sameGoalActions() {
    return [
      GSWButton(
        size: GSWButtonSize.large,
        label: widget.activeMatch.isMatched ? 'See my match' : 'See my request',
        onPressed: () => _choose(OpenRequestChoice.seeRequest),
      ),

      const SizedBox(height: 12),

      GSWButton(
        size: GSWButtonSize.large,
        variant: GSWButtonVariant.tertiary,
        label: 'Go to Home',
        onPressed: () => _choose(OpenRequestChoice.goHome),
      ),
    ];
  }

  List<Widget> _differentGoalActions() {
    return [
      Text(
        'Sending this one closes your open request. You can ask about it again any time.',
        textAlign: TextAlign.center,
        style: GSWTextStyles.bodySmall.copyWith(
          fontSize: 13,
          height: 19 / 13,
          color: GSWColors.textSecondary,
        ),
      ),

      const SizedBox(height: 12),

      GSWButton(
        size: GSWButtonSize.large,
        label: 'Send this one instead',
        onPressed: () => _choose(OpenRequestChoice.sendNew),
      ),

      const SizedBox(height: 12),

      GSWButton(
        size: GSWButtonSize.large,
        variant: GSWButtonVariant.secondary,
        label: 'Keep my open request',
        onPressed: () => _choose(OpenRequestChoice.keepOpen),
      ),
    ];
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.label,
    required this.chip,
    required this.title,
    required this.meta,
    this.highlighted = false,
  });

  final String label;
  final Widget chip;
  final String title;
  final String meta;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: GSWColors.surfacePrimary,
        borderRadius: BorderRadius.circular(GSWRadius.card),
        border: Border.all(
          color: highlighted ? GSWColors.borderFocused : GSWColors.surfaceInteractive,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GSWTextStyles.labelExtraSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 15 / 11,
                    color: GSWColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              chip,
            ],
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: GSWTextStyles.titleExtraSmall.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 24 / 17,
              color: GSWColors.textPrimary,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            meta,
            style: GSWTextStyles.bodySmall.copyWith(
              fontSize: 13,
              height: 19 / 13,
              color: GSWColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma 3.6 "Note added" row (node 1002:3125): 8px lime dot in a 20px line
/// box, 10px gap, Outfit Medium 14/20 title and Outfit Regular 13/19 quote.
class _NoteAddedRow extends StatelessWidget {
  const _NoteAddedRow({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 8,
          height: 20,
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: GSWColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We added your new note to it',
                style: GSWTextStyles.labelMedium.copyWith(
                  color: GSWColors.textPrimary,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\u201C$note\u201D',
                style: GSWTextStyles.bodyMedium.copyWith(
                  color: GSWColors.textSecondary,
                  fontSize: 13,
                  height: 19 / 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
