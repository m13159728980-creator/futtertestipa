import 'package:flutter/material.dart';
import 'package:app/models/settings.dart';

class AppTheme {
  static const Color telegramBlue = Color(0xFF229ED9);
  static const Color telegramGreen = Color(0xFF31A24C);
  static const Color darkBackground = Color(0xFF17212B);
  static const Color darkSurface = Color(0xFF232E3C);

  static ThemeData lightFor(AppAccentColor accentColor) {
    final seed = _seed(accentColor);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: telegramGreen,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF4F8FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: telegramBlue,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: telegramGreen,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: seed, width: 2),
        ),
      ),
    );
  }

  static ThemeData darkFor(AppAccentColor accentColor) {
    final seed = _seed(accentColor);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: seed,
      secondary: telegramGreen,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: telegramGreen,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: seed, width: 2),
        ),
      ),
    );
  }

  static ThemeData get light => lightFor(AppAccentColor.blue);
  static ThemeData get dark => darkFor(AppAccentColor.blue);

  static Color _seed(AppAccentColor accentColor) {
    return switch (accentColor) {
      AppAccentColor.blue => telegramBlue,
      AppAccentColor.green => telegramGreen,
      AppAccentColor.purple => const Color(0xFF7E57C2),
      AppAccentColor.pink => const Color(0xFFE91E63),
      AppAccentColor.orange => const Color(0xFFFF8A00),
    };
  }
}
