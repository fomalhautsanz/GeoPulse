import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app-wide look: Roboto, GeoPulse colours, and how text fields and
/// dropdowns are drawn. `main.dart` hands this to MaterialApp.
ThemeData buildAppTheme() {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    fontFamily: 'Roboto', // bundled in assets/fonts, see pubspec.yaml
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      error: AppColors.brand,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    // Mobile app: no ink ripples or hover highlights. Press feedback comes
    // from the Pressable widget instead.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    // Text fields and dropdowns: light grey, rounded, red outline on focus.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.brand),
      border: border(AppColors.outline),
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.brand, 1.5),
      errorBorder: border(AppColors.brand),
      focusedErrorBorder: border(AppColors.brand, 1.5),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.brand),
  );
}
