import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/config/theme.dart';

const _themeKey = 'theme_mode';
const _paletteKey = 'app_palette';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier();
});

final appPaletteProvider = StateNotifierProvider<AppPaletteNotifier, AppPalette>((ref) {
  return AppPaletteNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    state = AppThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
}

class AppPaletteNotifier extends StateNotifier<AppPalette> {
  AppPaletteNotifier() : super(AppPalette.purple) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_paletteKey);
    if (value != null) {
      state = AppPalette.values.firstWhere(
        (p) => p.name == value,
        orElse: () => AppPalette.purple,
      );
    }
  }

  Future<void> setPalette(AppPalette palette) async {
    state = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }
}
