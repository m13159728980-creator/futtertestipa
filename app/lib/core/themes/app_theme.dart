import 'package:flutter/material.dart';

class AppTheme {
  static const Color telegramBlue = Color(0xFF229ED9);
  static const Color telegramGreen = Color(0xFF31A24C);
  static const Color darkBackground = Color(0xFF17212B);
  static const Color darkSurface = Color(0xFF232E3C);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: telegramBlue,
      brightness: Brightness.light,
      primary: telegramBlue,
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
          borderSide: const BorderSide(color: telegramBlue, width: 2),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: telegramBlue,
      brightness: Brightness.dark,
      primary: telegramBlue,
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
          borderSide: const BorderSide(color: telegramBlue, width: 2),
        ),
      ),
    );
  }
}
