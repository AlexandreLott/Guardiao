import 'package:flutter/material.dart';

/// Nome exibido nas telas.
const guardianName = 'Guardian';

/// Cores do design.
abstract final class GColors {
  static const blue = Color(0xFF2B59FF);
  static const blueSoft = Color(0xFFE8EDFF);
  static const blueMid = Color(0xFFA6BAFF);
  static const orange = Color(0xFFFF7A1A);
  static const orangeDark = Color(0xFFD95F00);
  static const orangeSoft = Color(0xFFFFEBDC);
  static const lime = Color(0xFFB5E61D);
  static const green = Color(0xFF12B76A);
  static const greenText = Color(0xFF027A48);
  static const greenSoft = Color(0xFFDDF5E8);
  static const red = Color(0xFFE5484D);
  static const redText = Color(0xFFC62828);
  static const redSoft = Color(0xFFFDE4E4);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF7F8FA);
  static const card = Colors.white;
  static const track = Color(0xFFE9EEF7);
}

/// Família de fonte do design (Lexend, embutida no app).
const guardianFont = 'Lexend';

ThemeData guardiaoTheme([Brightness brightness = Brightness.light]) {
  // O design só existe no claro; o escuro não é oferecido.
  final scheme =
      ColorScheme.fromSeed(
        seedColor: GColors.blue,
        brightness: Brightness.light,
      ).copyWith(
        primary: GColors.blue,
        onPrimary: Colors.white,
        primaryContainer: GColors.blueSoft,
        onPrimaryContainer: GColors.blue,
        secondary: GColors.orange,
        onSecondary: Colors.white,
        secondaryContainer: GColors.greenSoft,
        onSecondaryContainer: GColors.greenText,
        tertiary: GColors.green,
        error: GColors.redText,
        errorContainer: GColors.redSoft,
        onErrorContainer: GColors.redText,
        surface: GColors.card,
        onSurface: GColors.ink,
        onSurfaceVariant: GColors.muted,
        outline: GColors.line,
        outlineVariant: GColors.line,
        surfaceContainerHighest: GColors.track,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: guardianFont,
    scaffoldBackgroundColor: GColors.bg,
  );

  final text = base.textTheme
      .apply(bodyColor: GColors.ink, displayColor: GColors.ink)
      .copyWith(
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: GColors.ink,
          height: 1.15,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: GColors.ink,
          height: 1.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: GColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: GColors.ink,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: GColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: GColors.muted,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: GColors.muted,
          height: 1.45,
        ),
        bodySmall: const TextStyle(
          fontSize: 12.5,
          color: GColors.muted,
          height: 1.4,
        ),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      );

  final radius14 = BorderRadius.circular(14);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: GColors.bg,
      foregroundColor: GColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      labelStyle: text.bodyMedium,
      border: border(GColors.line),
      enabledBorder: border(GColors.line),
      focusedBorder: border(GColors.blue, 1.6),
      errorBorder: border(GColors.red),
      disabledBorder: border(GColors.line),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: GColors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x140F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEDF1F7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GColors.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: GColors.blueMid,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: GColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GColors.blue,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? GColors.blue
            : const Color(0xFFCBD5E1),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(color: GColors.line, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
