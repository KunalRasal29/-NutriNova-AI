import 'package:flutter/material.dart';

class NovaColors {
  static const ink = Color(0xFF18211F);
  static const surface = Color(0xFFF7F8F4);
  static const panel = Color(0xFFFFFFFF);
  static const mint = Color(0xFF14A38B);
  static const lime = Color(0xFF9CCB3B);
  static const coral = Color(0xFFE66F51);
  static const gold = Color(0xFFE3A635);
  static const violet = Color(0xFF7765D8);
  static const graphite = Color(0xFF5E6964);
  static const border = Color(0xFFE2E8E2);
  static const danger = Color(0xFFD64949);
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
        color: NovaColors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: NovaColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NovaColors.panel,
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
          backgroundColor: NovaColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NovaColors.ink,
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
      scaffoldBackgroundColor: const Color(0xFF111614),
      colorScheme: ColorScheme.fromSeed(
        seedColor: NovaColors.mint,
        brightness: Brightness.dark,
        primary: NovaColors.mint,
        secondary: NovaColors.coral,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111614),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF18211F),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2B3834)),
        ),
      ),
    );
  }
}
