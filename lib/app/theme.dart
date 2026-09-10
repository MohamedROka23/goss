import 'package:flutter/material.dart';

class GossColors {
  static const navy = Color(0xFF0C2340);
  static const navy2 = Color(0xFF143258);
  static const ink = Color(0xFF1C2430);
  static const muted = Color(0xFF66707C);
  static const line = Color(0xFFE6E9EE);
  static const bg = Color(0xFFF6F7F9);
  static const white = Color(0xFFFFFFFF);
  static const red = Color(0xFFD21F26);
  static const blue = Color(0xFF1D6FBF);
  static const green = Color(0xFF1F8A4C);
  static const darkBg = Color(0xFF08162B);
  static const darkSurface = Color(0xFF0E2140);
  static const darkCard = Color(0xFF12274A);
  static const darkLine = Color(0xFF223A61);
  static const darkInk = Color(0xFFE8EDF5);
  static const darkMuted = Color(0xFF9AAAC0);
  static const topBar = Color(0xFF111111);
}

ThemeData gossTheme({bool isArabic = false, bool dark = false}) {
  final isDark = dark;

  final bg = isDark ? GossColors.darkBg : GossColors.white;
  final surface = isDark ? GossColors.darkSurface : GossColors.white;
  final card = isDark ? GossColors.darkCard : GossColors.white;
  final line = isDark ? GossColors.darkLine : GossColors.line;
  final ink = isDark ? GossColors.darkInk : GossColors.ink;
  final muted = isDark ? GossColors.darkMuted : GossColors.muted;

  final base = ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    fontFamily: isArabic ? 'Noto Sans Arabic' : 'Segoe UI',
    colorScheme: ColorScheme.fromSeed(
      seedColor: GossColors.navy,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: GossColors.navy,
      secondary: GossColors.red,
      surface: surface,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: GossColors.navy,
      foregroundColor: GossColors.white,
      elevation: 0,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 4,
      shadowColor: GossColors.navy.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: line),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    dividerTheme: DividerThemeData(color: line),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: surface,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: GossColors.blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: ink),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GossColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: GossColors.navy,
      indicatorColor: Colors.white.withValues(alpha: 0.08),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12);
        }
        return TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white);
        }
        return IconThemeData(color: Colors.white.withValues(alpha: 0.7));
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GossColors.navy,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}

ThemeData gossDarkTheme({bool isArabic = false}) =>
    gossTheme(isArabic: isArabic, dark: true);

/// Helpers to read the correct colour for the current light/dark mode.
extension GossModeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Background of regular cards/surfaces (white in light, dark card in dark).
  Color get cardColor => isDarkMode ? GossColors.darkCard : GossColors.white;

  /// Large full-width section background (white or light grey in light mode).
  Color get sectionColor => isDarkMode ? GossColors.darkSurface : GossColors.white;

  /// Alternative section band (light grey in light mode).
  Color get altSectionColor => isDarkMode ? GossColors.darkBg : GossColors.bg;

  /// Primary heading / title text colour.
  Color get headingColor => isDarkMode ? GossColors.white : GossColors.navy;

  /// Main body text colour.
  Color get bodyColor => isDarkMode ? GossColors.darkInk : GossColors.ink;

  /// Secondary / muted text colour.
  Color get mutedColor => isDarkMode ? GossColors.darkMuted : GossColors.muted;
}
