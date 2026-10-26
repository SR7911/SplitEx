import 'dart:async';
import 'dart:convert';
import 'package:split_ex/models/expenses_widget_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/config/router.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/providers/theme_provider.dart';
import 'package:split_ex/providers/expenses_widget_settings_provider.dart';

const _channel = MethodChannel('com.splitex.in.app/expenses_widget');

/// Keeps the launcher snapshot current while the app is running. No background
/// authentication or network access is performed by the native widget.
class ExpensesWidgetSync extends ConsumerStatefulWidget {
  final Widget child;
  const ExpensesWidgetSync({super.key, required this.child});
  @override
  ConsumerState<ExpensesWidgetSync> createState() => _ExpensesWidgetSyncState();
}

class _ExpensesWidgetSyncState extends ConsumerState<ExpensesWidgetSync>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _pendingAction;
  bool _checking = false;
  String? _lastPayload;
  String? _lastOwner;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> _update(Map<String, Object> data) async {
    try {
      await _channel.invokeMethod<void>('update', data);
    } on PlatformException catch (e) {
      _lastPayload = null;
      debugPrint('Expenses widget update failed: ${e.code}');
    } on MissingPluginException catch (_) {
      _lastPayload = null;
      // Allows Flutter tests and older native installations to run.
    }
  }

  Future<void> _consumeAction() async {
    if (_checking) return;
    _checking = true;
    try {
      _pendingAction ??= await _channel.invokeMethod<String>('consumeAction');
      if (!mounted || _pendingAction == null) return;
      if (ref.read(authStateProvider).valueOrNull == null ||
          ref.read(profileExistsProvider).valueOrNull != true) {
        return;
      }
      final action = _pendingAction!;
      _pendingAction = null;
      ref
          .read(routerProvider)
          .go(
            action == 'budgets'
                ? '/personal/budgets'
                : '/personal/transactions${action == 'add' ? '?add=true&request=${DateTime.now().microsecondsSinceEpoch}' : ''}',
          );
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_supported) {
      final auth = ref.watch(authStateProvider);
      final profile = ref.watch(profileExistsProvider);
      final owner = auth.valueOrNull?.uid;
      if (owner != _lastOwner) {
        _lastOwner = owner;
        _lastPayload = null;
      }
      final now = DateTime.now();
      final month = DateFormat('yyyy-MM').format(now);
      final mode = ref.watch(themeModeProvider);
      final appearance = ref.watch(expensesWidgetSettingsProvider);
      Map<String, Object>? data;
      if (!auth.isLoading && auth.valueOrNull == null) {
        data = {
          'budget': 'Sign in to SplitEx',
        }; // Clear previous user's snapshot.
      } else if (auth.valueOrNull != null) {
        data = {'userId': auth.valueOrNull!.uid};
        final transactions = ref.watch(personalTransactionsProvider(month));
        if (transactions.hasError) {
          data = {'userId': auth.valueOrNull!.uid, 'state': 'error'};
        } else if (!transactions.isLoading && transactions.hasValue) {
          try {
            data = ExpensesWidgetSnapshot.fromTransactions(
              userId: auth.valueOrNull!.uid,
              monthKey: month,
              transactions: transactions.requireValue,
            ).toPayload();
          } on FormatException catch (_) {
            data = {'userId': auth.valueOrNull!.uid, 'state': 'error'};
          }
        }
      }
      if (data != null) {
        data.addAll(appearance.toPayload());
        data['themeMode'] = mode.name;
        // Android resolves system appearance even when Flutter is closed.
        for (final positive in [true, false]) {
          for (final dark in [true, false]) {
            final colors = AppTheme.financialHeroColors(
              isPositive: positive,
              isDark: dark,
            );
            final key =
                '${positive ? 'positive' : 'negative'}${dark ? 'Dark' : 'Light'}';
            data['${key}Start'] = colors.first.toARGB32();
            data['${key}End'] = colors.last.toARGB32();
          }
        }
      }
      // Run platform work after rendering and after authentication settles.
      // Never publish unmasked defaults before persisted privacy settings load.
      final snapshot = appearance.isLoaded ? data : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (snapshot != null) {
          final signature = jsonEncode(snapshot);
          if (_lastPayload != signature) {
            _lastPayload = signature;
            unawaited(_update(snapshot));
          }
        }
        if (!auth.isLoading && !profile.isLoading) unawaited(_consumeAction());
      });
    }
    return widget.child;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
