import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Large text and big tap targets for users less comfortable with apps.
class AppTheme {
  static ThemeData get light {
    // Logo orange for buttons (the seed alone gives brown); white background,
    // like the logo images and the launch screens.
    final colors = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primaryDeep,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 16)),
      // White when scrolled too (no Material tint), with a light shadow.
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black26,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Flat white cards with a light outline, so lists stay calm and readable.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
