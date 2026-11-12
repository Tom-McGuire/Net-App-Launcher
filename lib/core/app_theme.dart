import 'package:flutter/material.dart';

/// Immutable set of color tokens for one brightness.
class _Palette {
  final Color scaffoldBackground;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color inputFill;
  final Color inputBorder;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primaryAccent;
  final Color success;
  final Color warning;
  final Color error;
  final Color onFilled;

  const _Palette({
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.inputFill,
    required this.inputBorder,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryAccent,
    required this.success,
    required this.warning,
    required this.error,
    required this.onFilled,
  });
}

/// Design tokens and synchronized light/dark desktop theme conforming to
/// "Network & Systems Desktop Applications: UI & Design Principles".
///
/// Colors are runtime getters that resolve against [isDark]. [isDark] is kept
/// in sync with the suite-wide `theme_mode` setting stored in
/// `SharedDeviceDatabase`; the root app rebuilds when it changes.
class AppTheme {
  AppTheme._();

  /// Global runtime toggle, updated when the shared theme mode changes.
  static bool isDark = true;

  /// Shared-database string representation of the current mode.
  static String get themeMode => isDark ? 'dark' : 'light';

  /// Applies a shared-database theme mode string (`'dark'` / `'light'`).
  static void applyThemeMode(String mode) => isDark = mode != 'light';

  static const _Palette _dark = _Palette(
    scaffoldBackground: Color(0xFF141414),
    surface: Color(0xFF1E1E1E),
    surfaceHigh: Color(0xFF222222),
    surfaceHighest: Color(0xFF323232),
    inputFill: Color(0xFF252526),
    inputBorder: Color(0xFF3E3E42),
    border: Color(0xFF2C2C2C),
    textPrimary: Color(0xFFE0E0E0),
    textSecondary: Color(0xFF9E9E9E),
    textMuted: Color(0xFF6E6E6E),
    primaryAccent: Color(0xFF007ACC),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    onFilled: Colors.black,
  );

  // "Clean Technical Slate" light palette.
  static const _Palette _light = _Palette(
    scaffoldBackground: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF9FAFB),
    surfaceHighest: Color(0xFFE5E7EB),
    inputFill: Color(0xFFF9FAFB),
    inputBorder: Color(0xFFD1D5DB),
    border: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF6B7280),
    primaryAccent: Color(0xFF0284C7),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    onFilled: Colors.white,
  );

  static _Palette get _p => isDark ? _dark : _light;

  // Surface & structural tokens
  static Color get scaffoldBackground => _p.scaffoldBackground;
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get surfaceHighest => _p.surfaceHighest;
  static Color get inputFill => _p.inputFill;
  static Color get inputBorder => _p.inputBorder;
  static Color get border => _p.border;

  // Typography tokens
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMuted => _p.textMuted;

  // Semantic & action tokens
  static Color get primaryAccent => _p.primaryAccent;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get error => _p.error;

  /// Foreground for text/icons placed on filled success/accent/warning buttons.
  static Color get onFilled => _p.onFilled;

  // Typography Styles
  static const TextStyle monospaceStyle = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    letterSpacing: 0.3,
  );

  /// Theme matching the current [isDark] value.
  static ThemeData get currentTheme => isDark ? darkTheme() : lightTheme();

  static ThemeData darkTheme() => _buildTheme(Brightness.dark, _dark);

  static ThemeData lightTheme() => _buildTheme(Brightness.light, _light);

  static ThemeData _buildTheme(Brightness brightness, _Palette p) {
    final isDarkTheme = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.scaffoldBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primaryAccent,
        brightness: brightness,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        outline: p.inputBorder,
        outlineVariant: p.border,
        surfaceContainerLowest: p.scaffoldBackground,
        surfaceContainerLow:
            isDarkTheme ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
        surfaceContainer: p.surfaceHigh,
        surfaceContainerHigh:
            isDarkTheme ? const Color(0xFF282828) : const Color(0xFFF3F4F6),
        surfaceContainerHighest: p.surfaceHighest,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: p.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: p.primaryAccent, width: 1.5),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
