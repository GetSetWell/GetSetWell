import 'package:flutter/material.dart';

@immutable
class GSWTypography extends ThemeExtension<GSWTypography> {
  const GSWTypography({
    required this.displayExtraSmall,
    required this.titleExtraSmall,
    required this.bodyExtraSmall,
    required this.labelExtraSmall,
    required this.caption,
  });

  final TextStyle displayExtraSmall;
  final TextStyle titleExtraSmall;
  final TextStyle bodyExtraSmall;
  final TextStyle labelExtraSmall;
  final TextStyle caption;

  @override
  GSWTypography copyWith({
    TextStyle? displayExtraSmall,
    TextStyle? titleExtraSmall,
    TextStyle? bodyExtraSmall,
    TextStyle? labelExtraSmall,
    TextStyle? caption,
  }) {
    return GSWTypography(
      displayExtraSmall: displayExtraSmall ?? this.displayExtraSmall,
      titleExtraSmall: titleExtraSmall ?? this.titleExtraSmall,
      bodyExtraSmall: bodyExtraSmall ?? this.bodyExtraSmall,
      labelExtraSmall: labelExtraSmall ?? this.labelExtraSmall,
      caption: caption ?? this.caption,
    );
  }

  @override
  GSWTypography lerp(covariant ThemeExtension<GSWTypography>? other, double t) {
    if (other is! GSWTypography) return this;

    return GSWTypography(
      displayExtraSmall: TextStyle.lerp(displayExtraSmall, other.displayExtraSmall, t)!,
      titleExtraSmall: TextStyle.lerp(titleExtraSmall, other.titleExtraSmall, t)!,
      bodyExtraSmall: TextStyle.lerp(bodyExtraSmall, other.bodyExtraSmall, t)!,
      labelExtraSmall: TextStyle.lerp(labelExtraSmall, other.labelExtraSmall, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}

class GSWTextStyles {
  GSWTextStyles._();

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 56,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 48,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 34,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle displayExtraSmall = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // Headings
  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 30,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 26,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // Title
  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle titleExtraSmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
  );

  static const TextStyle bodyExtraSmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle labelExtraSmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}
