import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpensesWidgetSettings {
  final String style, tone;
  final bool dots, redAccent, hideAmounts, decimals, progress;
  final bool isLoaded;
  const ExpensesWidgetSettings({
    this.style = 'nothing',
    this.tone = 'dark',
    this.dots = true,
    this.redAccent = true,
    this.hideAmounts = false,
    this.decimals = true,
    this.progress = true,
    this.isLoaded = true,
  });

  ExpensesWidgetSettings copyWith({
    String? style,
    String? tone,
    bool? dots,
    bool? redAccent,
    bool? hideAmounts,
    bool? decimals,
    bool? progress,
    bool? isLoaded,
  }) => ExpensesWidgetSettings(
    style: style ?? this.style,
    tone: tone ?? this.tone,
    dots: dots ?? this.dots,
    redAccent: redAccent ?? this.redAccent,
    hideAmounts: hideAmounts ?? this.hideAmounts,
    decimals: decimals ?? this.decimals,
    progress: progress ?? this.progress,
    isLoaded: isLoaded ?? this.isLoaded,
  );

  Map<String, Object> toPayload() => {
    'widgetStyle': style,
    'widgetTone': tone,
    'widgetDots': dots ? 1 : 0,
    'widgetRedAccent': redAccent ? 1 : 0,
    'widgetHideAmounts': hideAmounts ? 1 : 0,
    'widgetDecimals': decimals ? 1 : 0,
    'widgetProgress': progress ? 1 : 0,
  };

  factory ExpensesWidgetSettings.fromMap(Map<String, dynamic> map) =>
      ExpensesWidgetSettings(
        style: map['widgetStyle'] == 'hero' ? 'hero' : 'nothing',
        tone: ['dark', 'light', 'system'].contains(map['widgetTone'])
            ? map['widgetTone'] as String
            : 'dark',
        dots: map['widgetDots'] != 0,
        redAccent: map['widgetRedAccent'] != 0,
        hideAmounts: map['widgetHideAmounts'] == 1,
        decimals: map['widgetDecimals'] != 0,
        progress: map['widgetProgress'] != 0,
      );
}

final expensesWidgetSettingsProvider =
    StateNotifierProvider<
      ExpensesWidgetSettingsNotifier,
      ExpensesWidgetSettings
    >((ref) => ExpensesWidgetSettingsNotifier());

class ExpensesWidgetSettingsNotifier
    extends StateNotifier<ExpensesWidgetSettings> {
  static const storageKey = 'expenses_widget_appearance_v1';
  bool _edited = false;
  late final Future<void> loaded;
  ExpensesWidgetSettingsNotifier() : super(const ExpensesWidgetSettings(isLoaded: false)) {
    loaded = _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (!mounted || _edited) return;
    if (raw == null) {
      state = const ExpensesWidgetSettings();
      return;
    }
    try {
      state = ExpensesWidgetSettings.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException catch (_) {
      state = const ExpensesWidgetSettings();
      // Keep defaults if an old or damaged preference cannot be decoded.
    } on TypeError catch (_) {
      state = const ExpensesWidgetSettings();
      // Unknown preference schemas should not prevent startup.
    }
  }

  Future<void> update(ExpensesWidgetSettings settings) async {
    _edited = true;
    state = settings.copyWith(isLoaded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toPayload()));
  }
}
