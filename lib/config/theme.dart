import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppPalette { purple, blue, teal, emerald, charcoal, rose, orange, indigo, cyan, amber }

enum AppThemeMode { light, dark, deepDark, system }

class AppTheme {
  static const _palettes = <AppPalette, _PaletteColors>{
    AppPalette.purple: _PaletteColors(
      light: Color(0xFF7C4DFF),
      dark: Color(0xFFB388FF),
      name: 'Purple',
    ),
    AppPalette.blue: _PaletteColors(
      light: Color(0xFF2563EB),
      dark: Color(0xFF60A5FA),
      name: 'Deep Blue',
    ),
    AppPalette.teal: _PaletteColors(
      light: Color(0xFF0D9488),
      dark: Color(0xFF5EEAD4),
      name: 'Teal',
    ),
    AppPalette.emerald: _PaletteColors(
      light: Color(0xFF059669),
      dark: Color(0xFF6EE7B7),
      name: 'Emerald',
    ),
    AppPalette.charcoal: _PaletteColors(
      light: Color(0xFF1F2937),
      dark: Color(0xFF9CA3AF),
      name: 'Charcoal',
    ),
    AppPalette.rose: _PaletteColors(
      light: Color(0xFFE11D48),
      dark: Color(0xFFFB7185),
      name: 'Rose',
    ),
    AppPalette.orange: _PaletteColors(
      light: Color(0xFFEA580C),
      dark: Color(0xFFFB923C),
      name: 'Orange',
    ),
    AppPalette.indigo: _PaletteColors(
      light: Color(0xFF4338CA),
      dark: Color(0xFFA5B4FC),
      name: 'Indigo',
    ),
    AppPalette.cyan: _PaletteColors(
      light: Color(0xFF0891B2),
      dark: Color(0xFF67E8F9),
      name: 'Cyan',
    ),
    AppPalette.amber: _PaletteColors(
      light: Color(0xFFD97706),
      dark: Color(0xFFFBBF24),
      name: 'Amber',
    ),
  };

  static String paletteName(AppPalette palette) => _palettes[palette]!.name;

  static Color paletteColor(AppPalette palette) => _palettes[palette]!.light;

  static ThemeData lightTheme(AppPalette palette) {
    final primary = _palettes[palette]!.light;
    const bg = Color(0xFFF8F9FE);
    const fontFamily = 'Gilmer';

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        titleSmall: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontWeight: FontWeight.w400),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        surface: bg,
        error: const Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: primary,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: primary),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withOpacity(0.1),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E)),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400, fontSize: 13, color: Color(0xFF6B7280)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: fontFamily),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, fontFamily: fontFamily),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData darkTheme(AppPalette palette) {
    final primary = _palettes[palette]!.dark;
    const bg = Color(0xFF000000);
    const surface = Color(0xFF111111);
    const cardColor = Color(0xFF1C1C1C);
    const fontFamily = 'Gilmer';

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        titleSmall: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontWeight: FontWeight.w400),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        surface: surface,
        surfaceTint: Colors.transparent,
        error: const Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: primary,
        foregroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.black),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: primary,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
          color: Colors.black,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: primary),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: fontFamily),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withOpacity(0.15),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08), thickness: 1),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400, fontSize: 13, color: Colors.white70),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        indicatorColor: Colors.black,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: fontFamily),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, fontFamily: fontFamily),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData deepDarkTheme(AppPalette palette) {
    final base = darkTheme(palette);
    const bg = Color(0xFF000000);
    const surface = Color(0xFF000000);
    const cardColor = Color(0xFF0A0A0A);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(surface: surface),
      cardTheme: base.cardTheme.copyWith(color: cardColor),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF000000),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF000000),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(fillColor: cardColor),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0A0A0A)),
    );
  }
}

class _PaletteColors {
  final Color light;
  final Color dark;
  final String name;
  const _PaletteColors({required this.light, required this.dark, required this.name});
}
