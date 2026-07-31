import 'package:flutter/material.dart';

class NovaColors {
  static const ink = Color(0xFF070A12);
  static const surface = Color(0xFF0B1020);
  static const panel = Color(0xFF11182A);
  static const panelRaised = Color(0xFF172238);
  static const panelSoft = Color(0xFF0E1627);
  static const glass = Color(0xD9141D31);
  static const mint = Color(0xFF42E8B4);
  static const blue = Color(0xFF6EA8FF);
  static const electric = Color(0xFF7B7CFF);
  static const aqua = Color(0xFF4DD9FF);
  static const lime = Color(0xFFB7E66B);
  static const coral = Color(0xFFFF7185);
  static const gold = Color(0xFFFFCA63);
  static const violet = Color(0xFFA994FF);
  static const graphite = Color(0xFFB6BED1);
  static const muted = Color(0xFF7D89A4);
  static const border = Color(0xFF263653);
  static const borderBright = Color(0xFF3B5278);
  static const danger = Color(0xFFFF6375);
  static const success = Color(0xFF36E1AC);

  static const premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6A75FF), Color(0xFF4E9BFF), Color(0xFF35D9B0)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D2B4B), Color(0xFF121C32), Color(0xFF102A2C)],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1426), Color(0xFF090E1A), Color(0xFF070A12)],
  );
}

class NovaSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class NovaRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

class NovaShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ];
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
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NovaColors.surface,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
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
        shadowColor: Colors.black.withValues(alpha: 0.22),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.lg),
          side: BorderSide(color: NovaColors.border.withValues(alpha: 0.75)),
        ),
      ),
      textTheme: Typography.whiteCupertino.apply(
        fontFamily: 'Roboto',
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: NovaColors.graphite,
          backgroundColor: NovaColors.panelSoft.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NovaRadius.sm),
          ),
        ),
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
          borderRadius: BorderRadius.circular(NovaRadius.md),
          borderSide: const BorderSide(color: NovaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.md),
          borderSide: const BorderSide(color: NovaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.md),
          borderSide: const BorderSide(color: NovaColors.mint, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.md),
          borderSide: const BorderSide(color: NovaColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NovaRadius.md),
          borderSide: const BorderSide(color: NovaColors.danger, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.lg,
          vertical: 15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: NovaColors.electric,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NovaRadius.md),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: NovaColors.borderBright),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NovaRadius.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NovaColors.panelSoft,
        selectedColor: NovaColors.blue.withValues(alpha: 0.2),
        side: const BorderSide(color: NovaColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.pill),
        ),
        labelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: NovaColors.panelRaised,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.md),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NovaColors.panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: NovaColors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NovaColors.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.lg),
          side: const BorderSide(color: NovaColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NovaColors.mint,
        linearTrackColor: NovaColors.border,
        circularTrackColor: NovaColors.border,
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
        shadowColor: Colors.black.withValues(alpha: 0.22),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.lg),
          side: const BorderSide(color: NovaColors.border),
        ),
      ),
    );
  }
}
