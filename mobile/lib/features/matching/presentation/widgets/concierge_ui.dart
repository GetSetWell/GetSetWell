import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/routing/gsw_routes.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared pieces for the Help me choose, matching and request status screens.

// -----------------------------------------------------------------------------
// Navigation
// -----------------------------------------------------------------------------

/// Pops when there is something to pop, otherwise goes home. Screens in this
/// flow can be opened with go(), push() or from a notification, so a bare pop
/// can leave the user on an empty stack.
void conciergeSafePop<T extends Object?>(BuildContext context, [T? result]) {
  if (context.canPop()) {
    context.pop<T>(result);
  } else {
    context.go(GSWRoutes.home);
  }
}

// -----------------------------------------------------------------------------
// Request status
// -----------------------------------------------------------------------------

class ConciergeStatus {
  ConciergeStatus._();

  /// Statuses where the request is finished. 'booked' and 'confirmed' both mean
  /// the request became a session.
  static const Set<String> closed = {
    'confirmed',
    'booked',
    'completed',
    'closed',
    'cancelled',
    'canceled',
    'lost',
  };

  static const Set<String> booked = {'confirmed', 'booked', 'completed'};

  static const Set<String> cancelled = {'cancelled', 'canceled', 'lost', 'closed'};

  static String normalise(Object? status) => status?.toString().trim().toLowerCase() ?? '';

  static bool isClosed(String status) => closed.contains(normalise(status));

  static bool isBooked(String status) => booked.contains(normalise(status));

  static bool isCancelled(String status) => cancelled.contains(normalise(status));

  static bool isMatched(String status) => normalise(status) == 'matched';

  /// The four named states from Figma 9.2 plus Cancelled.
  static String label(String status) {
    final value = normalise(status);

    if (value == 'matched') return 'Recommendation ready';
    if (booked.contains(value)) return 'Session booked';
    if (cancelled.contains(value)) return 'Cancelled';
    if (value == 'new' || value == 'pending' || value.isEmpty) return 'Request submitted';

    return 'Matching in progress';
  }
}

// -----------------------------------------------------------------------------
// Copy helpers
// -----------------------------------------------------------------------------

class ConciergeCopy {
  ConciergeCopy._();

  static String capitalise(String value) => GSWPronoun.capitalise(value.trim());

  static String goalHeadline(String? goal) {
    switch (goal?.trim().toLowerCase()) {
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
        return capitalise(goal ?? '');
    }
  }

  static String shortDay(String value) {
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
        return capitalise(value);
    }
  }

  static List<String> days(Object? raw) {
    if (raw is! List) return const [];

    return raw.map((day) => day.toString().trim()).where((day) => day.isNotEmpty).toList();
  }

  /// "Mon, Wed, Fri".
  static String daysShortList(List<String> days) => days.map(shortDay).join(', ');

  /// "weekday mornings", "weekends", "Mon and Wed evenings".
  static String daysAndTimePhrase(List<String> days, String time) {
    final lower = days.map((day) => day.toLowerCase()).toSet();
    const weekdays = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday'};
    const weekend = {'saturday', 'sunday'};

    String dayText;
    if (lower.isNotEmpty && lower.every(weekdays.contains)) {
      dayText = lower.length == 5 ? 'weekday' : _joinAnd(days.map(shortDay).toList());
    } else if (lower.isNotEmpty && lower.every(weekend.contains)) {
      dayText = 'weekend';
    } else {
      dayText = _joinAnd(days.map(shortDay).toList());
    }

    final timeText = timePlural(time);

    if (dayText.isEmpty) return timeText;
    if (timeText.isEmpty) return dayText;

    return '$dayText $timeText';
  }

  static String timePlural(String time) {
    switch (time.trim().toLowerCase()) {
      case 'morning':
        return 'mornings';
      case 'afternoon':
        return 'afternoons';
      case 'evening':
        return 'evenings';
      default:
        return time.trim().toLowerCase();
    }
  }

  static String _joinAnd(List<String> values) {
    if (values.isEmpty) return '';
    if (values.length == 1) return values.first;

    return '${values.sublist(0, values.length - 1).join(', ')} and ${values.last}';
  }

  /// Short label for the training place chosen in Help me choose.
  static String placeLabel(String? locationName) {
    final value = locationName?.trim().toLowerCase() ?? '';

    if (value.contains('home')) return 'Home';
    if (value.contains('gym')) return 'Gym';
    if (value.contains('outdoor')) return 'Outdoors';

    return capitalise(locationName ?? '');
  }

  /// "at a gym in Dubai Marina", "at your home in JLT", "outdoors in Barsha".
  static String placePhrase(String? locationName, String area) {
    final value = locationName?.trim().toLowerCase() ?? '';
    final inArea = area.trim().isEmpty ? '' : ' in ${area.trim()}';

    if (value.contains('home')) return 'at your home$inArea';
    if (value.contains('gym')) return 'at a gym$inArea';
    if (value.contains('outdoor')) return 'outdoors$inArea';
    if (area.trim().isNotEmpty) return 'in ${area.trim()}';

    return '';
  }

  /// "AED 200 to 300".
  static String? budgetRange(num? min, num? max) {
    if (min == null || max == null) return null;
    if (min == max) return GSWMoney.aed(min);

    return 'AED ${GSWMoney.amount(min)} to ${GSWMoney.amount(max)}';
  }

  /// "Yesterday at 9:12 AM", "Today at 7:00 AM", "Sat 19 Sep at 9:12 AM".
  static String sentAt(DateTime? dubai, {String separator = ' at '}) {
    if (dubai == null) return 'Recently';

    final now = GSWTime.nowDubai();
    final String day;

    if (GSWTime.isSameDay(dubai, now)) {
      day = 'Today';
    } else if (GSWTime.isSameDay(dubai, now.subtract(const Duration(days: 1)))) {
      day = 'Yesterday';
    } else {
      day = GSWTime.dayShort(dubai);
    }

    return '$day$separator${GSWTime.time(dubai)}';
  }

  /// When the customer will hear back. We promise the morning after the
  /// request was sent (12:00 PM Dubai at the latest).
  static String recommendationPromise(DateTime? sentDubai) {
    final sent = sentDubai ?? GSWTime.nowDubai();
    final now = GSWTime.nowDubai();
    final deadline = DateTime.utc(sent.year, sent.month, sent.day + 1, 12);

    if (now.isAfter(deadline)) {
      return 'Very soon, in the app and on WhatsApp.';
    }

    if (GSWTime.isSameDay(deadline, now.add(const Duration(days: 1)))) {
      return 'By tomorrow morning, in the app and on WhatsApp.';
    }

    return 'By ${GSWTime.time(deadline)} today, in the app and on WhatsApp.';
  }
}

// -----------------------------------------------------------------------------
// Images
// -----------------------------------------------------------------------------

/// Trainer images are stored either as a full URL or as a path in the
/// trainer-images bucket.
String? conciergeTrainerImageUrl(String? path) {
  final value = path?.trim() ?? '';

  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;

  return Supabase.instance.client.storage.from('trainer-images').getPublicUrl(value);
}

String conciergeInitials(String name) {
  final initials = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  return initials.isEmpty ? 'T' : initials;
}

/// Round trainer photo with an initials placeholder for missing or broken images.
class ConciergeTrainerAvatar extends StatelessWidget {
  const ConciergeTrainerAvatar({
    super.key,
    required this.name,
    required this.imagePath,
    this.size = 48,
  });

  final String name;
  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = conciergeTrainerImageUrl(imagePath);

    final placeholder = Container(
      width: size,
      height: size,
      color: GSWColors.surfaceInteractive,
      alignment: Alignment.center,
      child: Text(
        conciergeInitials(name),
        style: GSWTextStyles.labelLarge.copyWith(color: GSWColors.textAccent),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? placeholder
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.8),
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Buttons
// -----------------------------------------------------------------------------

/// 46px round back button with the lime arrowhead (Figma "Back").
class ConciergeBackButton extends StatelessWidget {
  const ConciergeBackButton({super.key, required this.onTap, this.overlay = false});

  final VoidCallback onTap;

  /// True on photos: adds the 40% dark fill behind the arrow.
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: overlay ? GSWColors.backgroundOverlay : null,
            border: Border.all(color: GSWColors.borderSecondary),
          ),
          child: SvgPicture.asset(
            GSWIcons.arrowheadLeft,
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(GSWColors.iconAccent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

/// Text-only action (Figma "Alts"): Outfit Medium 14.
class ConciergeTextAction extends StatelessWidget {
  const ConciergeTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GSWRadius.inner),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GSWTextStyles.bodyMedium.copyWith(
            color: accent ? GSWColors.textAccent : GSWColors.textSecondary,
            fontWeight: FontWeight.w500,
            height: 20 / 14,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom sheets
// -----------------------------------------------------------------------------

Future<T?> showConciergeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    // GSWSheetDragDismiss handles dragging anywhere on the sheet.
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: GSWColors.scrim,
    builder: (sheetContext) => GSWSheetDragDismiss(
      enabled: isDismissible,
      child: builder(sheetContext),
    ),
  );
}

/// Standard GetSetWell sheet body: grabber zone, 16px sides, 28px bottom,
/// 20px gap between children, safe-area aware, keyboard aware.
class ConciergeSheet extends StatelessWidget {
  const ConciergeSheet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) spaced.add(const SizedBox(height: 20));
      spaced.add(children[index]);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: GSWColors.backgroundPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + media.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 28,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GSWColors.surfaceInteractive,
                      borderRadius: BorderRadius.circular(GSWRadius.full),
                    ),
                  ),
                ),
              ),
              ...spaced,
            ],
          ),
        ),
      ),
    );
  }
}

class ConciergeSheetHeading extends StatelessWidget {
  const ConciergeSheetHeading({super.key, required this.title, this.intro});

  final String title;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
        ),
        if (intro != null) ...[
          const SizedBox(height: 20),
          Text(
            intro!,
            style: GSWTextStyles.bodyMedium.copyWith(
              color: GSWColors.textSecondary,
              height: 20 / 14,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small grey status chip (Figma "Chip"): Medium 11 on surface/interactive.
class ConciergeStatusChip extends StatelessWidget {
  const ConciergeStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GSWColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(GSWRadius.full),
      ),
      child: Text(
        label,
        style: GSWTextStyles.bodyExtraSmall.copyWith(
          color: GSWColors.textPrimary,
          fontWeight: FontWeight.w500,
          height: 12 / 11,
        ),
      ),
    );
  }
}
