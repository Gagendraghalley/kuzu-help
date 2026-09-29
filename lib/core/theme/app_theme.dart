import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Large text and big tap targets for users less comfortable with apps.
/// White cards with hairline edges on a warm canvas, set in Plus Jakarta Sans
/// (assets/fonts/): calm, and clearly one brand.
class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData get light {
    // Logo orange for buttons (the seed alone gives brown); the warm neutrals
    // in AppColors instead of Material's grey-blue ones.
    final colors = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primaryDeep,
      onPrimary: Colors.white,
      primaryContainer: AppColors.peach,
      onPrimaryContainer: AppColors.maroon,
      secondaryContainer: AppColors.peach,
      onSecondaryContainer: AppColors.maroon,
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFCFAF7),
      surfaceContainer: const Color(0xFFF9F6F2),
      surfaceContainerHigh: AppColors.canvas,
      surfaceContainerHighest: AppColors.sand,
      outline: AppColors.outline,
      outlineVariant: AppColors.line,
      error: AppColors.error,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colors, fontFamily: fontFamily);
    final text = _textTheme(base.textTheme);
    final button = text.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1);
    final shape16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: Colors.white,
      dividerColor: AppColors.line,
      // Same colour as the screen, so the bar and the page read as one; a
      // hairline shadow once content scrolls under it.
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        titleTextStyle: text.titleMedium!.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        iconTheme: const IconThemeData(color: AppColors.ink),
        actionsIconTheme: const IconThemeData(color: AppColors.ink),
        actionsPadding: const EdgeInsets.only(right: 8),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      // White cards with a hairline edge; rounded, and clipped so ripples
      // stay inside the corners.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape16,
          textStyle: button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: shape16,
          textStyle: button,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.outline, width: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: shape16,
          textStyle: button.copyWith(fontSize: 15.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape16,
          textStyle: button,
          elevation: 0,
          backgroundColor: AppColors.peach,
          foregroundColor: AppColors.primaryDeep,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDeep,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: button,
      ),
      // White fields with a soft edge that turns orange while typing.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? AppColors.canvas : Colors.white,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _inputBorder(AppColors.outline),
        enabledBorder: _inputBorder(AppColors.outline),
        disabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.primaryDeep, width: 1.8),
        errorBorder: _inputBorder(AppColors.error),
        focusedErrorBorder: _inputBorder(AppColors.error, width: 1.8),
        labelStyle: text.bodyLarge!.copyWith(color: AppColors.muted),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => text.bodyLarge!.copyWith(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.error)
                ? AppColors.error
                : states.contains(WidgetState.focused)
                    ? AppColors.primaryDeep
                    : AppColors.muted,
          ),
        ),
        hintStyle: text.bodyLarge!.copyWith(color: AppColors.muted.withValues(alpha: 0.8)),
        helperStyle: text.bodySmall!.copyWith(color: AppColors.muted),
        errorStyle: text.bodySmall!.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        prefixStyle: text.bodyLarge!.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
      ),
      // Grey for chevrons and menus; leading icons bring their own colour
      // (IconTile, CategoryIcon).
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.muted,
        titleTextStyle: text.bodyLarge!.copyWith(fontWeight: FontWeight.w600, height: 1.3),
        subtitleTextStyle: text.bodyMedium!.copyWith(fontSize: 14.5, color: AppColors.muted, height: 1.4),
        leadingAndTrailingTextStyle: text.bodyMedium!.copyWith(fontSize: 14, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 12,
        horizontalTitleGap: 14,
        selectedColor: AppColors.primaryDeep,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.peach,
        checkmarkColor: AppColors.primaryDeep,
        labelStyle: text.labelLarge!.copyWith(color: AppColors.ink),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected) ? AppColors.primaryDeep : AppColors.outline,
            width: 1.2,
          ),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          textStyle: WidgetStatePropertyAll(text.labelLarge!.copyWith(fontWeight: FontWeight.w700)),
          shape: WidgetStatePropertyAll(shape16),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.outline, width: 1.2)),
          backgroundColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.primaryDeep : Colors.white,
          ),
          foregroundColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
        ),
        trackOutlineColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : AppColors.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.outline, width: 1.6),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryDeep,
        linearTrackColor: AppColors.sand,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        textStyle: text.labelSmall!.copyWith(fontWeight: FontWeight.w800),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge!.copyWith(fontWeight: FontWeight.w800),
        contentTextStyle: text.bodyLarge!.copyWith(color: AppColors.inkSoft),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        modalBarrierColor: Colors.black.withValues(alpha: 0.45),
        dragHandleColor: AppColors.outline,
        dragHandleSize: const Size(44, 5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        actionTextColor: AppColors.saffron,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: text.bodySmall!.copyWith(color: Colors.white),
      ),
    );
  }

  /// Tighter, heavier headings and roomy body text, in the brand's ink.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle style(TextStyle? from, double size, FontWeight weight, {double spacing = 0, double? height}) =>
        from!.copyWith(fontSize: size, fontWeight: weight, letterSpacing: spacing, height: height);

    return base
        .copyWith(
          displaySmall: style(base.displaySmall, 34, FontWeight.w800, spacing: -0.8, height: 1.15),
          headlineMedium: style(base.headlineMedium, 28, FontWeight.w800, spacing: -0.6, height: 1.2),
          headlineSmall: style(base.headlineSmall, 24, FontWeight.w800, spacing: -0.5, height: 1.25),
          titleLarge: style(base.titleLarge, 20, FontWeight.w700, spacing: -0.3, height: 1.3),
          titleMedium: style(base.titleMedium, 17, FontWeight.w700, spacing: -0.2, height: 1.35),
          titleSmall: style(base.titleSmall, 15, FontWeight.w600, spacing: -0.1, height: 1.35),
          bodyLarge: style(base.bodyLarge, 16, FontWeight.w400, height: 1.5),
          bodyMedium: style(base.bodyMedium, 16, FontWeight.w400, height: 1.45),
          bodySmall: style(base.bodySmall, 13.5, FontWeight.w500, height: 1.4),
          labelLarge: style(base.labelLarge, 15, FontWeight.w600),
          labelMedium: style(base.labelMedium, 13, FontWeight.w600, spacing: 0.1),
          labelSmall: style(base.labelSmall, 12, FontWeight.w600, spacing: 0.2),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.2}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
}
