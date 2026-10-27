import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/app/constants.dart';
import 'package:split_ex/app/navigation/router.dart';
import 'package:split_ex/shared/ui/theme.dart';
import 'package:split_ex/modules/settings/providers/theme_provider.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_service.dart';
import 'package:split_ex/modules/settings/services/expenses_widget_sync.dart';

class SplitExApp extends ConsumerStatefulWidget {
  const SplitExApp({super.key});

  @override
  ConsumerState<SplitExApp> createState() => _SplitExAppState();
}

class _SplitExAppState extends ConsumerState<SplitExApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(bankSmsServiceProvider).start();
    ref.listenManual(authStateProvider, (_, next) {
      if (!next.isLoading) unawaited(_syncSms(next.valueOrNull?.uid));
    }, fireImmediately: true);
  }

  Future<void> _syncSms(String? uid) async {
    final service = ref.read(bankSmsServiceProvider);
    try {
      await service.bindUser(uid);
      if (uid != null && service.enabled) await service.process();
    } catch (_) {
      // SMS capture is optional and must never block app startup or sign-in.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authStateProvider);
    if (state == AppLifecycleState.resumed && !auth.isLoading) {
      unawaited(_syncSms(auth.valueOrNull?.uid));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      builder: (context, child) => ExpensesWidgetSync(child: child!),
    );
  }
}
