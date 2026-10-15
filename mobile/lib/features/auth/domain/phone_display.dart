import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// "+971501234567" -> "+971 50 123 4567". Falls back to the raw value.
String formatPhoneForDisplay(String phone) {
  try {
    final parsed = PhoneNumber.parse(phone);

    final formattedNsn = parsed.formatNsn(format: NsnFormat.international);

    return '+${parsed.countryCode} $formattedNsn';
  } catch (_) {
    return phone;
  }
}
