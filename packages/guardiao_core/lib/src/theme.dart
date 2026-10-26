import 'package:flutter/material.dart';

/// Cores do protótipo: roxo (primária) e verde (secundária), Material 3.
const guardiaoPurple = Color(0xFF6750A4);
const guardiaoGreen = Color(0xFF386A20);

ThemeData guardiaoTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: guardiaoPurple,
    secondary: guardiaoGreen,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
