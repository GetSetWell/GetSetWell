import 'package:flutter/material.dart';

import 'gsw_colors.dart';
import 'gsw_typography.dart';

class GSWTheme {
  GSWTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.dark,

      scaffoldBackgroundColor: GSWColors.backgroundPrimary,

      colorScheme: ColorScheme.dark(
        primary: GSWColors.primary,
        primaryContainer: GSWColors.backgroundPrimary,
        error: GSWColors.error,
        onPrimary: GSWColors.backgroundPrimary,
        onSurface: GSWColors.textPrimary,
        onError: Colors.white,
      ),

      textTheme:
          const TextTheme(
            //display
            displayLarge: GSWTextStyles.displayLarge,
            displayMedium: GSWTextStyles.displayMedium,
            displaySmall: GSWTextStyles.displaySmall,

            //headings
            headlineLarge: GSWTextStyles.headingLarge,
            headlineMedium: GSWTextStyles.headingMedium,
            headlineSmall: GSWTextStyles.headingSmall,

            //title
            titleLarge: GSWTextStyles.titleLarge,
            titleMedium: GSWTextStyles.titleMedium,
            titleSmall: GSWTextStyles.titleSmall,

            //body
            bodyLarge: GSWTextStyles.bodyLarge,
            bodyMedium: GSWTextStyles.bodyMedium,
            bodySmall: GSWTextStyles.bodySmall,

            //label
            labelLarge: GSWTextStyles.labelLarge,
            labelMedium: GSWTextStyles.labelMedium,
            labelSmall: GSWTextStyles.labelSmall,
          ).apply(
            bodyColor: GSWColors.textPrimary,
            displayColor: GSWColors.textPrimary,
          ),
    );
  }
}
