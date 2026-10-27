import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/settings/providers/expenses_widget_settings_provider.dart';
import 'package:split_ex/modules/settings/screens/expenses_widget_settings_screen.dart';
import 'package:split_ex/modules/settings/widgets/dot_matrix_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved privacy and appearance are restored before widget sync is ready', () async {
    SharedPreferences.setMockInitialValues({
      ExpensesWidgetSettingsNotifier.storageKey: jsonEncode(const ExpensesWidgetSettings(
        tone: 'light', hideAmounts: true, redAccent: false, dots: false,
      ).toPayload()),
    });
    final notifier = ExpensesWidgetSettingsNotifier();
    addTearDown(notifier.dispose);
    expect(notifier.state.isLoaded, isFalse);
    await notifier.loaded;
    expect(notifier.state.isLoaded, isTrue);
    expect(notifier.state.hideAmounts, isTrue);
    expect(notifier.state.tone, 'light');
    expect(notifier.state.redAccent, isFalse);
    expect(notifier.state.dots, isFalse);
  });

  test('a user edit made during startup is saved and not overwritten by loading', () async {
    final notifier = ExpensesWidgetSettingsNotifier();
    addTearDown(notifier.dispose);
    await notifier.update(const ExpensesWidgetSettings(style: 'hero', hideAmounts: true));
    await notifier.loaded;
    final restored = ExpensesWidgetSettingsNotifier();
    addTearDown(restored.dispose);
    await restored.loaded;
    expect(restored.state.style, 'hero');
    expect(restored.state.hideAmounts, isTrue);
    expect(restored.state.isLoaded, isTrue);
  });

  test('damaged settings fall back without leaving sync permanently waiting', () async {
    SharedPreferences.setMockInitialValues({ExpensesWidgetSettingsNotifier.storageKey: '{broken'});
    final notifier = ExpensesWidgetSettingsNotifier();
    addTearDown(notifier.dispose);
    await notifier.loaded;
    expect(notifier.state.isLoaded, isTrue);
    expect(notifier.state.style, 'nothing');
  });

  testWidgets('hidden preview masks all amounts and spending progress', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(width: 320,
      child: ExpensesWidgetPreview(settings: ExpensesWidgetSettings(hideAmounts: true)),
    ))));
    expect(find.byWidgetPredicate((widget) => widget is DotMatrixLabel && widget.text == '••••'), findsNWidgets(3));
    expect(find.byWidgetPredicate((widget) => widget is DotMatrixLabel && widget.text.contains('₹')), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('150.0'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(DotMatrixProgress), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final tone in ['dark', 'light']) {
    testWidgets('$tone preview fits a compact widget width', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 280,
        child: ExpensesWidgetPreview(settings: ExpensesWidgetSettings(tone: tone)),
      ))));
      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate((widget) => widget is DotMatrixLabel && widget.text == 'Overspent by'), findsOneWidget);
      expect(find.byType(DotMatrixProgress), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  }
}
