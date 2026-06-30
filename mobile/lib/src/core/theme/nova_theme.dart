import 'package:flutter/material.dart';

class NovaColors {
  static const ink = Color(0xFF10121E);
  static const surface = Color(0xFF121420);
  static const panel = Color(0xFF222432);
  static const panelRaised = Color(0xFF2A2D3B);
  static const panelSoft = Color(0xFF191B27);
  static const mint = Color(0xFF20D59B);
  static const blue = Color(0xFF4DA3FF);
  static const lime = Color(0xFFB6E35B);
  static const coral = Color(0xFFFF6B7B);
  static const gold = Color(0xFFFFC857);
  static const violet = Color(0xFFA58BFF);
  static const graphite = Color(0xFF9CA3B8);
  static const muted = Color(0xFF6E7488);
  static const border = Color(0xFF333647);
  static const danger = Color(0xFFFF5A68);
}

class NovaSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class NovaTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: NovaColors.mint,
      brightness: Brightness.light,
      primary: NovaColors.mint,
      secondary: NovaColors.coral,
      surface: NovaColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NovaColors.surface,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: NovaColors.surface,
        foregroundColor: NovaColors.ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: NovaColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: NovaColors.panelRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: NovaColors.border.withValues(alpha: 0.75)),
        ),
      ),
      textTheme: Typography.whiteCupertino.apply(
        fontFamily: 'Roboto',
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: NovaColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NovaColors.panelSoft,
        hintStyle: const TextStyle(color: NovaColors.muted),
        labelStyle: const TextStyle(color: NovaColors.graphite),
        prefixIconColor: NovaColors.graphite,
        suffixIconColor: NovaColors.graphite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NovaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NovaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NovaColors.mint, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: NovaColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: NovaColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = light();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NovaColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: NovaColors.blue,
        brightness: Brightness.dark,
        primary: NovaColors.blue,
        secondary: NovaColors.coral,
        surface: NovaColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: NovaColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: NovaColors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: NovaColors.border),
        ),
      ),
    );
  }
}
