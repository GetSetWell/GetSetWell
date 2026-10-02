class UAEPhoneValidator {
  const UAEPhoneValidator._();

  /// Returns only the UAE mobile part after +971.
  ///
  /// Accepts pasted formats such as:
  /// 0501234567
  /// 501234567
  /// +971501234567
  /// +971 50 123 4567
  static String normalize(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('971')) {
      digits = digits.substring(3);
    }

    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits;
  }

  static bool isValid(String value) {
    final number = normalize(value);

    return RegExp(r'^(50|52|54|55|56|58)\d{7}$').hasMatch(number);
  }

  static String? errorText(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    if (!isValid(value)) {
      return 'Enter a valid UAE mobile number';
    }

    return null;
  }

  static String toE164(String value) {
    return '+971${normalize(value)}';
  }
}
