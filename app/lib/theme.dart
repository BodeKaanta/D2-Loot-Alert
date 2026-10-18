import 'package:flutter/material.dart';

/// Destiny-inspired palette: near-black blue-grays, off-white text, gold accent.
/// (Colors can't be copyrighted; these are picked to feel like the in-game menus.)
abstract final class AppColors {
  static const background = Color(0xFF0B0E11);
  static const surface = Color(0xFF151A1F);
  static const border = Color(0x26FFFFFF); // white at 15%
  static const tileBorder = Color(0x4DFFFFFF); // white at 30%, for item tiles
  static const textPrimary = Color(0xFFE9E7E2);
  static const textSecondary = Color(0xFF8B939C);
  static const exotic = Color(0xFFCEAE33); // Destiny's exotic gold
}

/// Text styles. Headers are set in caps with wide letter spacing like Destiny's
/// menus; widgets call `.toUpperCase()` on the text themselves.
abstract final class AppText {
  static const _font = 'Inter';

  static const appTitle = TextStyle(
      fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 3.2,
      color: AppColors.textPrimary);
  /// The Today screen's two big parts: "BONUS FOCUS" and "FEATURED THIS WEEK".
  static const groupTitle = TextStyle(
      fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3.0,
      color: AppColors.textPrimary);

  /// Section headers ("PINNACLE OPS", "RAIDS"): bigger than the card titles
  /// under them, so they're easy to spot while scrolling fast.
  static const sectionHeader = TextStyle(
      fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2.2,
      color: AppColors.textPrimary);
  static const cardTitle = TextStyle(
      fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.8,
      color: AppColors.textPrimary);
  static const tabLabel = TextStyle(
      fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4);
  static const label = TextStyle(
      fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.6,
      color: AppColors.textSecondary);
  static const itemName = TextStyle(
      fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const itemType = TextStyle(
      fontFamily: _font, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const body = TextStyle(
      fontFamily: _font, fontSize: 14, height: 1.45, color: AppColors.textPrimary);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.textPrimary,
      secondary: AppColors.exotic,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    // Destiny's menus don't ripple; keep only a faint highlight on press.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.white10,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.appTitle,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: AppText.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.tileBorder)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.textPrimary),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.tileBorder),
        shape: const RoundedRectangleBorder(), // square corners, like the in-game UI
        textStyle: AppText.label,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}
