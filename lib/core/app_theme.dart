import 'package:flutter/material.dart';

/// Design tokens and dark-first desktop theme conforming to
/// "Network & Systems Desktop Applications: UI & Design Principles".
class AppTheme {
  // Theme Color Tokens
  static const Color scaffoldBackground = Color(0xFF141414);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceHigh = Color(0xFF222222);
  static const Color surfaceHighest = Color(0xFF323232);
  static const Color inputFill = Color(0xFF252526);
  static const Color border = Color(0xFF2C2C2C);
  static const Color primaryAccent = Color(0xFF007ACC);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Typography Styles
  static const TextStyle monospaceStyle = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    letterSpacing: 0.3,
  );

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: Brightness.dark,
        surface: surface,
        surfaceContainerLowest: scaffoldBackground,
        surfaceContainerLow: const Color(0xFF1A1A1A),
        surfaceContainer: surfaceHigh,
        surfaceContainerHigh: const Color(0xFF282828),
        surfaceContainerHighest: surfaceHighest,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3E3E42)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF3E3E42)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryAccent, width: 1.5),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
