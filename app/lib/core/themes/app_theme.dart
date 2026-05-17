import 'package:flutter/material.dart';
import 'package:app/core/services/ios_ui_capability_service.dart';
import 'package:app/models/settings.dart';

class AppTheme {
  static const Color telegramBlue = Color(0xFF229ED9);
  static const Color telegramGreen = Color(0xFF31A24C);
  static const Color darkBackground = Color(0xFF17212B);
  static const Color darkSurface = Color(0xFF232E3C);

  static ThemeData lightFor(
    AppAccentColor accentColor, {
    IosInterfaceLevel interfaceLevel = IosInterfaceLevel.material,
  }) {
    final seed = _seed(accentColor);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: telegramGreen,
      surface: Colors.white,
    );

    return _withPlatformStyling(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: interfaceLevel == IosInterfaceLevel.liquidGlass
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFF4F8FB),
        appBarTheme: AppBarTheme(
          backgroundColor: interfaceLevel == IosInterfaceLevel.material
              ? telegramBlue
              : Colors.white.withValues(alpha: 0.82),
          foregroundColor: interfaceLevel == IosInterfaceLevel.material
              ? Colors.white
              : const Color(0xFF111827),
          centerTitle: false,
          elevation: interfaceLevel == IosInterfaceLevel.material ? null : 0,
          scrolledUnderElevation: 0,
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
      ),
      interfaceLevel,
    );
  }

  static ThemeData darkFor(
    AppAccentColor accentColor, {
    IosInterfaceLevel interfaceLevel = IosInterfaceLevel.material,
  }) {
    final seed = _seed(accentColor);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: seed,
      secondary: telegramGreen,
      surface: darkSurface,
    );

    return _withPlatformStyling(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: interfaceLevel == IosInterfaceLevel.liquidGlass
            ? const Color(0xFF0D141C)
            : darkBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: interfaceLevel == IosInterfaceLevel.material
              ? darkSurface
              : darkSurface.withValues(alpha: 0.78),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
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
      ),
      interfaceLevel,
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

  static ThemeData _withPlatformStyling(
    ThemeData theme,
    IosInterfaceLevel interfaceLevel,
  ) {
    if (interfaceLevel == IosInterfaceLevel.material) {
      return theme;
    }
    final borderRadius = interfaceLevel == IosInterfaceLevel.liquidGlass
        ? BorderRadius.circular(18)
        : BorderRadius.circular(12);
    return theme.copyWith(
      platform: TargetPlatform.iOS,
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: theme.cardTheme.copyWith(
        elevation: interfaceLevel == IosInterfaceLevel.liquidGlass ? 0 : 1,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: borderRadius.topLeft),
        ),
        modalBackgroundColor: theme.colorScheme.surface.withValues(
          alpha: interfaceLevel == IosInterfaceLevel.liquidGlass ? 0.88 : 1,
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
    );
  }
}
