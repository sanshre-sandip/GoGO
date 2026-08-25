import 'package:flutter/material.dart';

/// GoGo design tokens. Everything visual references these, nothing hard-codes.
abstract class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract class Radii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 28.0;
  static const pill = 999.0;
}

abstract class Brand {
  static const name = 'GoGo';
  static const tagline = 'Find your better ride.';
  static const primary = Color(0xFF4F46E5);
  static const accent = Color(0xFF22C55E);
}

ThemeData buildGoGoTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide.none,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    dividerTheme: const DividerThemeData(space: Spacing.lg),
  );
}
