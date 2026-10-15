// Shared money and Dubai-time formatting for every GetSetWell screen.
//
// Rules (from the FINAL Figma section and the v1.2 policy):
// - Money: "AED 250" for whole dirhams, "AED 12.50" otherwise. Never "250.0".
// - Maths is done in fils (1 AED = 100 fils) so 5% fees never drift.
// - Times are always Dubai time (UTC+4, no DST) on a 12-hour clock: "7:00 AM".

class GSWMoney {
  GSWMoney._();

  /// Client service fee, as a percentage of the session rate.
  static const int serviceFeePercent = 5;

  /// Converts dirhams to whole fils.
  static int toFils(num aed) => (aed * 100).round();

  /// Converts whole fils back to dirhams.
  static double fromFils(int fils) => fils / 100;

  /// 5% service fee on a session rate, rounded to the nearest fil.
  static double serviceFee(num sessionRate) =>
      fromFils((toFils(sessionRate) * serviceFeePercent / 100).round());

  /// Session rate plus the 5% service fee.
  static double totalWithFee(num sessionRate) =>
      fromFils(toFils(sessionRate) + toFils(serviceFee(sessionRate)));

  /// Half of an amount, rounded to the nearest fil.
  static double half(num amount) => fromFils((toFils(amount) / 2).round());

  /// "250", "12.50", "262.50".
  static String amount(num? value) {
    if (value == null) return '–';
    final fils = toFils(value);
    if (fils % 100 == 0) return (fils ~/ 100).toString();
    return (fils / 100).toStringAsFixed(2);
  }

  /// "AED 250", "AED 12.50". Returns an en dash for a missing amount.
  static String aed(num? value) => value == null ? '–' : 'AED ${amount(value)}';

  /// Safe parse of a Supabase numeric column (num, String or null).
  static double? parse(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class GSWTime {
  GSWTime._();

  static const Duration dubaiOffset = Duration(hours: 4);

  static const List<String> _weekdaysShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _weekdaysLong = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Wall-clock Dubai time for any instant. The result is a UTC DateTime whose
  /// fields read as Dubai time, so it never depends on the device time zone.
  static DateTime toDubai(DateTime value) => value.toUtc().add(dubaiOffset);

  /// Current Dubai wall-clock time.
  static DateTime nowDubai() => toDubai(DateTime.now());

  /// Parses a Supabase timestamp (assumed UTC when it carries no offset)
  /// and returns Dubai wall-clock time.
  static DateTime? parseToDubai(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return toDubai(value);
    final raw = value.toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
    final utc = hasOffset
        ? parsed.toUtc()
        : DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
            parsed.minute, parsed.second);
    return toDubai(utc);
  }

  /// Builds the UTC instant for a Dubai wall-clock date and time.
  static DateTime dubaiToUtc(int year, int month, int day,
          [int hour = 0, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).subtract(dubaiOffset);

  /// "7:00 AM". Input must already be Dubai time (from [toDubai]).
  static String time(DateTime dubai) {
    final hour12 = dubai.hour % 12 == 0 ? 12 : dubai.hour % 12;
    final minute = dubai.minute.toString().padLeft(2, '0');
    final period = dubai.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  /// "7:00 to 8:00 AM" or "11:00 AM to 12:00 PM".
  static String timeRange(DateTime startDubai, Duration length) {
    final end = startDubai.add(length);
    final samePeriod = (startDubai.hour < 12) == (end.hour < 12);
    if (samePeriod) {
      final startText = time(startDubai);
      return '${startText.substring(0, startText.length - 3)} to ${time(end)}';
    }
    return '${time(startDubai)} to ${time(end)}';
  }

  /// "Sat 19 Sep".
  static String dayShort(DateTime dubai) =>
      '${_weekdaysShort[dubai.weekday - 1]} ${dubai.day} ${_monthsShort[dubai.month - 1]}';

  /// "Saturday 19 September".
  static String dayLong(DateTime dubai) =>
      '${_weekdaysLong[dubai.weekday - 1]} ${dubai.day} ${_monthsLong[dubai.month - 1]}';

  /// "Sat".
  static String weekdayShort(DateTime dubai) => _weekdaysShort[dubai.weekday - 1];

  /// "Sep".
  static String monthShort(DateTime dubai) => _monthsShort[dubai.month - 1];

  /// "Sat 19 Sep, 7:00 AM".
  static String dayAndTime(DateTime dubai) => '${dayShort(dubai)}, ${time(dubai)}';

  /// True when two Dubai wall-clock values fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Today", "Tomorrow" or "Sat 19 Sep" relative to Dubai now.
  static String relativeDay(DateTime dubai) {
    final now = nowDubai();
    if (isSameDay(dubai, now)) return 'Today';
    if (isSameDay(dubai, now.add(const Duration(days: 1)))) return 'Tomorrow';
    return dayShort(dubai);
  }

  /// "Just now", "5 min ago", "3 hours ago", "Yesterday", "Sat 19 Sep".
  static String ago(DateTime dubai) {
    final diff = nowDubai().difference(dubai);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return dayShort(dubai);
  }
}

/// Neutral pronoun helpers so copy never assumes a trainer is male.
class GSWPronoun {
  GSWPronoun._();

  static bool? _isFemale(Object? gender) {
    if (gender is bool) return gender;
    final g = gender?.toString().toLowerCase().trim();
    if (g == null || g.isEmpty) return null;
    if (g == 'female' || g == 'f' || g == 'woman' || g == 'true') return true;
    if (g == 'male' || g == 'm' || g == 'man' || g == 'false') return false;
    return null;
  }

  /// "he", "she" or "they".
  static String subject(Object? gender) => switch (_isFemale(gender)) {
        true => 'she',
        false => 'he',
        null => 'they',
      };

  /// "his", "her" or "their".
  static String possessive(Object? gender) => switch (_isFemale(gender)) {
        true => 'her',
        false => 'his',
        null => 'their',
      };

  /// "him", "her" or "them".
  static String object(Object? gender) => switch (_isFemale(gender)) {
        true => 'her',
        false => 'him',
        null => 'them',
      };

  /// "fits" for he/she, "fit" for they.
  static String fitsVerb(Object? gender) => _isFemale(gender) == null ? 'fit' : 'fits';

  static String capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
