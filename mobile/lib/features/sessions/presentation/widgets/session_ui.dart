import 'package:flutter/material.dart';
import 'package:mobile/core/theme/gsw_radius.dart';
import 'package:mobile/core/widgets/sheets/gsw_sheet_drag_dismiss.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/constants/gsw_icons.dart';
import 'package:mobile/core/theme/gsw_colors.dart';
import 'package:mobile/core/theme/gsw_typography.dart';
import 'package:mobile/core/utils/gsw_format.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session length is fixed by policy.
const Duration kSessionLength = Duration(hours: 1);

// -----------------------------------------------------------------------------
// Data helpers shared by every sessions screen
// -----------------------------------------------------------------------------

/// Reads the trainer fields that the sessions queries join in.
class SessionTrainerInfo {
  const SessionTrainerInfo({
    required this.name,
    required this.gender,
    required this.imagePath,
    required this.primaryService,
    required this.pricePerSession,
  });

  factory SessionTrainerInfo.fromSession(Map<String, dynamic> session) {
    final raw = session['trainers'];
    final trainer = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final name = trainer['full_name']?.toString().trim() ?? '';

    String? primaryService;
    final services = trainer['trainer_services'];
    if (services is List) {
      for (final item in services) {
        if (item is! Map || item['is_primary'] != true) continue;
        final service = item['services'];
        if (service is Map) {
          final value = service['name']?.toString().trim();
          if (value != null && value.isNotEmpty) primaryService = value;
        }
        break;
      }
    }

    final image = trainer['profile_image_url']?.toString().trim();

    return SessionTrainerInfo(
      name: name.isEmpty ? 'Your trainer' : name,
      gender: trainer['gender'],
      imagePath: image == null || image.isEmpty ? null : image,
      primaryService: primaryService,
      pricePerSession: GSWMoney.parse(trainer['price_per_session']),
    );
  }

  final String name;
  final Object? gender;
  final String? imagePath;
  final String? primaryService;
  final double? pricePerSession;

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
  }

  /// The trainer's primary service, or the generic label when none is set.
  String get serviceLabel =>
      primaryService?.isNotEmpty == true ? primaryService! : 'Personal training';

  String get subject => GSWPronoun.subject(gender);
  String get possessive => GSWPronoun.possessive(gender);
  String get object => GSWPronoun.object(gender);
}

/// Amounts for an existing booking. Reads the price snapshot on the session,
/// falling back to the trainer's current price only for legacy rows.
class SessionAmounts {
  const SessionAmounts({
    required this.sessionRate,
    required this.serviceFee,
    required this.total,
  });

  factory SessionAmounts.fromSession(Map<String, dynamic> session) {
    final trainer = SessionTrainerInfo.fromSession(session);

    final snapshotRate = GSWMoney.parse(session['session_rate']);
    final rate = snapshotRate ?? trainer.pricePerSession;

    final snapshotFee = GSWMoney.parse(session['service_fee']);
    final fee = snapshotFee ?? (rate == null ? null : GSWMoney.serviceFee(rate));

    final snapshotTotal = GSWMoney.parse(session['total_amount']);
    final total = snapshotTotal ??
        (rate == null ? null : GSWMoney.fromFils(GSWMoney.toFils(rate) + GSWMoney.toFils(fee ?? 0)));

    return SessionAmounts(sessionRate: rate, serviceFee: fee, total: total);
  }

  final double? sessionRate;
  final double? serviceFee;
  final double? total;

  /// Half the session rate: the late cancellation refund and the pay-to-move amount.
  double? get halfRate => sessionRate == null ? null : GSWMoney.half(sessionRate!);
}

/// Statuses that mean a session is still booked.
const Set<String> kActiveSessionStatuses = {'confirmed', 'booked'};

String sessionStatus(Map<String, dynamic> session) =>
    session['status']?.toString().trim().toLowerCase() ?? '';

bool sessionIsCancelled(Map<String, dynamic> session) {
  final status = sessionStatus(session);
  return status == 'cancelled' || status == 'canceled';
}

/// Start time of a session as Dubai wall-clock time.
DateTime? sessionStartDubai(Map<String, dynamic> session) =>
    GSWTime.parseToDubai(session['scheduled_at']);

/// True for an ended, still-booked session with no answer yet, within the
/// 24 hours after it ended (after that it is treated as done).
bool sessionNeedsConfirmation(Map<String, dynamic> session) {
  if (!kActiveSessionStatuses.contains(sessionStatus(session))) return false;
  if ((session['customer_outcome']?.toString().trim() ?? '').isNotEmpty) return false;

  final start = DateTime.tryParse(session['scheduled_at']?.toString() ?? '');
  if (start == null) return false;

  final end = start.toUtc().add(kSessionLength);
  final now = DateTime.now().toUtc();
  return !now.isBefore(end) && now.isBefore(end.add(const Duration(hours: 24)));
}

/// Resolves a trainer image that may be a storage path or a full URL.
String? resolveTrainerImageUrl(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return Supabase.instance.client.storage.from('trainer-images').getPublicUrl(value);
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------

/// Round trainer photo with an initials fallback when there is no image or it
/// fails to load.
class SessionTrainerAvatar extends StatelessWidget {
  const SessionTrainerAvatar({
    super.key,
    required this.name,
    required this.imagePath,
    this.size = 24,
  });

  final String name;
  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = resolveTrainerImageUrl(imagePath);

    final fallback = _InitialsAvatar(name: name, size: size);

    if (url == null) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.8),
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'T'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: GSWColors.surfaceInteractive,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: GSWTextStyles.labelSmall.copyWith(
          color: GSWColors.textAccent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );
  }
}

/// 46px round back button with the lime arrowhead, as used across Story 10.
/// 10.1 draws the ring in border/secondary; 10.2 and later in
/// surface/interactive, so the ring colour is configurable.
class SessionBackButton extends StatelessWidget {
  const SessionBackButton({
    super.key,
    required this.onTap,
    this.borderColor = GSWColors.borderSecondary,
  });

  final VoidCallback onTap;
  final Color borderColor;

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
            border: Border.all(color: borderColor),
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

/// Opens a GetSetWell bottom sheet with the standard scrim.
Future<T?> showSessionSheet<T>({
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
    backgroundColor: Colors.transparent,
    barrierColor: GSWColors.scrim,
    builder: (sheetContext) => GSWSheetDragDismiss(
      enabled: isDismissible,
      child: builder(sheetContext),
    ),
  );
}

/// Standard sheet body: #000D1B fill, 28px top corners, 40x4 grabber in a 28px
/// zone, 16px sides, 28px bottom plus the safe area, 20px between children.
class SessionSheetFrame extends StatelessWidget {
  const SessionSheetFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) spaced.add(const SizedBox(height: 20));
      spaced.add(children[index]);
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: GSWColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSWRadius.sheet)),
      ),
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 28 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet heading, Outfit Bold 24.
class SessionSheetHeading extends StatelessWidget {
  const SessionSheetHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GSWTextStyles.titleLarge.copyWith(color: GSWColors.textPrimary, height: 30 / 24),
    );
  }
}

/// Sheet intro, Regular 14 secondary.
class SessionSheetIntro extends StatelessWidget {
  const SessionSheetIntro(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14),
    );
  }
}

/// Small centred footnote, Regular 12 / 16. Figma uses text/tertiary for the
/// payment and policy footnotes and text/secondary elsewhere.
class SessionFootnote extends StatelessWidget {
  const SessionFootnote(
    this.text, {
    super.key,
    this.align = TextAlign.center,
    this.color = GSWColors.textSecondary,
  });

  final String text;
  final TextAlign align;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: GSWTextStyles.bodySmall.copyWith(color: color, height: 16 / 12),
    );
  }
}

/// A bullet line used in "Good to know" and "What happens next" cards.
class SessionBullet extends StatelessWidget {
  const SessionBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Figma PrepCard item: an accent "·" glyph, 8px gap, Regular 14 / 20.
    final style = GSWTextStyles.bodyMedium.copyWith(color: GSWColors.textSecondary, height: 20 / 14);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('·', style: style.copyWith(color: GSWColors.textAccent)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
