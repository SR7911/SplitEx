import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/config/constants.dart';
import 'package:split_ex/config/router.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/providers/theme_provider.dart';

class SplitExApp extends ConsumerWidget {
  const SplitExApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appThemeMode = ref.watch(themeModeProvider);
    final palette = ref.watch(appPaletteProvider);

    final ThemeMode themeMode;
    final ThemeData darkTheme;

    switch (appThemeMode) {
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
        darkTheme = AppTheme.darkTheme(palette);
      case AppThemeMode.dark:
        themeMode = ThemeMode.dark;
        darkTheme = AppTheme.darkTheme(palette);
      case AppThemeMode.deepDark:
        themeMode = ThemeMode.dark;
        darkTheme = AppTheme.deepDarkTheme(palette);
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
        darkTheme = AppTheme.darkTheme(palette);
    }

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(palette),
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
