import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand palette lifted from the Unity shell app
/// (`main/src/main/res/values/colors.xml` in fulldive-unity-plugins).
abstract final class FulldiveColors {
  static const navy = Color(0xFF212E47);
  static const navyDeep = Color(0xFF1A2440);
  static const navySurface = Color(0xFF293958);
  static const navyToolbar = Color(0xFF263853);
  static const orange = Color(0xFFFA8A19);
  static const orangeDeep = Color(0xFFF78000);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xB3FFFFFF);
  static const textTertiary = Color(0x80FFFFFF);
  static const divider = Color(0x1AFFFFFF);
}

abstract final class FulldiveTheme {
  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: FulldiveColors.navyDeep,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: FulldiveColors.orange,
        onPrimary: Colors.white,
        secondary: FulldiveColors.orangeDeep,
        onSecondary: Colors.white,
        surface: FulldiveColors.navy,
        onSurface: FulldiveColors.textPrimary,
        surfaceContainerHighest: FulldiveColors.navySurface,
        outline: FulldiveColors.divider,
      ),
      scaffoldBackgroundColor: FulldiveColors.navy,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: FulldiveColors.navyDeep,
        foregroundColor: FulldiveColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlay,
      ),
      cardTheme: CardThemeData(
        color: FulldiveColors.navySurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: FulldiveColors.divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FulldiveColors.orange,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FulldiveColors.orangeDeep,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: FulldiveColors.textPrimary,
        displayColor: FulldiveColors.textPrimary,
      ),
    );
  }
}
