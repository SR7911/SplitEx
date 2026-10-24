import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/connectivity_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/personal_debts_screen.dart';
import 'package:split_ex/screens/personal/debt_list_screen.dart';
import 'package:split_ex/screens/personal/debt_dashboard_screen.dart';
import 'package:split_ex/screens/personal/debt_widgets.dart';

class _OnlineConnectivity extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _OnlineConnectivity() : super(ConnectivityStatus.online);
}

PersonalTransactionModel debt(
  String name,
  DebtType type, {
  bool settled = false,
  double paid = 0,
  double writtenOff = 0,
  DateTime? date,
  String category = 'Other',
  List<Map<String, dynamic>> history = const [],
}) {
  final created = date ?? DateTime.now();
  return PersonalTransactionModel(
    id: name,
    title: '$name debt',
    personName: name,
    amount: 1000,
    type: type == DebtType.lent
        ? TransactionType.expense
        : TransactionType.income,
    category: category,
    date: created,
    userId: 'test',
    month: DateFormat('yyyy-MM').format(created),
    createdAt: created,
    debtType: type,
    isSettled: settled,
    settledAmount: paid,
    writtenOffAmount: writtenOff,
    partialSettlements: history,
  );
}

Future<void> openScreen(
  WidgetTester tester,
  Widget screen,
  List<PersonalTransactionModel> debts,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(430, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityProvider.overrideWith((ref) => _OnlineConnectivity()),
        personalDebtsProvider.overrideWith((ref) => Stream.value(debts)),
        unreadCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, home: screen),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  test(
    'written off debt excludes unpaid loss from outstanding, preserving paid amount',
    () {
      final closed = debt(
        'Closed',
        DebtType.lent,
        settled: true,
        paid: 200,
        writtenOff: 800,
      );
      expect(closed.remainingAmount, 0);
      expect(closed.settledAmount, 200);
      expect(closed.writtenOffAmount, 800);
      expect(debt('Partial', DebtType.lent, paid: 200).remainingAmount, 800);
    },
  );

  testWidgets(
    'all-time debt tabs separate active lent, borrowed and settled debts',
    (tester) async {
      await openScreen(tester, const PersonalDebtsScreen(), [
        debt('Alice', DebtType.lent, date: DateTime(2025, 1, 10)),
        debt('Bob', DebtType.borrowed),
        debt('Carol', DebtType.lent, settled: true, paid: 1000),
      ]);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      await tester.tap(find.text('Borrowed').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      await tester.tap(find.text('Settled').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Carol'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'settlement sheet provides a date picker for both payment actions',
    (tester) async {
      await openScreen(
        tester,
        Scaffold(body: DebtTile(txn: debt('Alice', DebtType.lent))),
        [],
      );
      await tester.tap(find.text('Receive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Record money received'), findsOneWidget);
      expect(find.text('Still owed to you'), findsOneWidget);
      expect(find.text('Record Partial Receipt'), findsOneWidget);
      expect(find.text('Mark Fully Received'), findsOneWidget);
      await tester.tap(find.text('Received date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('close debt warns about losing the remaining balance', (
    tester,
  ) async {
    await openScreen(
      tester,
      Scaffold(body: DebtTile(txn: debt('Alice', DebtType.lent, paid: 200))),
      [],
    );
    await tester.tap(find.byTooltip('Debt actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close Debt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining('You will lose the unpaid ₹800.00'),
      findsOneWidget,
    );
    expect(find.text('Close & Write Off'), findsOneWidget);
    expect(find.text('Settlement date'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('monthly debt list excludes debts from another month', (
    tester,
  ) async {
    final now = DateTime.now();
    await openScreen(tester, const DebtListScreen(), [
      debt('ThisMonth', DebtType.lent),
      debt(
        'LastMonth',
        DebtType.lent,
        date: DateTime(now.year, now.month - 1, 10),
      ),
    ]);
    expect(find.text('Top Categories'), findsOneWidget);
    expect(find.text('LastMonth'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('category view all opens a sheet with every category', (
    tester,
  ) async {
    await openScreen(
      tester,
      Scaffold(
        body: DebtInsights(
          debts: [debt('Alice', DebtType.lent)],
          includeDetails: false,
        ),
      ),
      [],
    );
    await tester.tap(find.text('View All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Debt Categories'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DebtSheetFrame),
        matching: find.text('1 debt'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('monthly activity bars show currency tooltips when tapped', (
    tester,
  ) async {
    await openScreen(tester, const DebtDashboardScreen(), [
      debt('Alice', DebtType.lent),
    ]);
    await tester.scrollUntilVisible(
      find.byType(BarChart),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(BarChart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final chart = tester.getRect(find.byType(BarChart));
    await tester.tapAt(
      Offset(chart.left + chart.width * 11 / 12 - 5, chart.top + 50),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    final tooltip = data.barTouchData.touchTooltipData.getTooltipItem(
      data.barGroups.last,
      5,
      data.barGroups.last.barRods.first,
      0,
    );
    expect(tooltip?.text, contains('Lent: ₹1,000'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'tapping a debt opens the original transaction with edit action',
    (tester) async {
      final original = debt('Alice', DebtType.lent);
      await openScreen(tester, Scaffold(body: DebtTile(txn: original)), [
        original,
      ]);
      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'monthly categories expand and collapse in place including categories after the top three',
    (tester) async {
      await openScreen(tester, const DebtListScreen(), [
        debt('Alice', DebtType.lent, category: 'Food'),
        debt('Bob', DebtType.borrowed, category: 'Travel'),
        debt('Carol', DebtType.lent, category: 'Shopping'),
        debt('David', DebtType.borrowed, category: 'Other'),
      ]);
      expect(find.text('Food'), findsNothing);
      await tester.tap(find.byTooltip('Expand categories'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final category in ['Food', 'Travel', 'Shopping', 'Other']) {
        expect(find.text(category), findsOneWidget);
      }
      expect(find.byType(DebtSheetFrame), findsNothing);
      expect(find.text('View All'), findsNothing);
      await tester.tap(find.byTooltip('Collapse categories'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Food'), findsNothing);
      expect(find.byTooltip('Expand categories'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('borrowed money uses repayment actions and a repayment date', (
    tester,
  ) async {
    await openScreen(
      tester,
      Scaffold(body: DebtTile(txn: debt('Bob', DebtType.borrowed))),
      [],
    );
    expect(find.text('Repay'), findsOneWidget);
    expect(find.text('Receive'), findsNothing);
    await tester.tap(find.text('Repay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Record repayment'), findsOneWidget);
    expect(find.text('You still owe'), findsOneWidget);
    expect(find.text('Record Partial Repayment'), findsOneWidget);
    expect(find.text('Mark Fully Repaid'), findsOneWidget);
    expect(find.text('Record Partial Receipt'), findsNothing);
    await tester.tap(find.text('Repayment date'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'each list tile shows only its own receipt or repayment history inline',
    (tester) async {
      final lent = debt(
        'Alice',
        DebtType.lent,
        paid: 200,
        history: [
          {
            'amount': 200,
            'date': '2026-10-03T10:00:00',
            'note': 'Alice transfer',
          },
        ],
      );
      final borrowed = debt(
        'Bob',
        DebtType.borrowed,
        settled: true,
        paid: 1000,
        history: [
          {
            'amount': 1000,
            'date': '2026-10-04T10:00:00',
            'note': 'Bob bank payment',
            'type': 'payment',
          },
        ],
      );
      await openScreen(
        tester,
        Scaffold(
          body: ListView(
            children: [
              DebtTile(txn: lent),
              DebtTile(txn: borrowed),
            ],
          ),
        ),
        [],
      );
      final aliceTile = find.byWidgetPredicate(
        (widget) => widget is DebtTile && widget.txn.id == 'Alice',
      );
      final bobTile = find.byWidgetPredicate(
        (widget) => widget is DebtTile && widget.txn.id == 'Bob',
      );
      expect(find.text('Settlement History'), findsNWidgets(2));
      expect(
        find.descendant(of: aliceTile, matching: find.text('Alice transfer')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aliceTile, matching: find.text('Received')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aliceTile, matching: find.text('03 Oct 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aliceTile, matching: find.text('₹200')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aliceTile, matching: find.text('Bob bank payment')),
        findsNothing,
      );
      expect(
        find.descendant(of: bobTile, matching: find.text('Bob bank payment')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bobTile, matching: find.text('Repaid')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bobTile, matching: find.text('04 Oct 2026')),
        findsOneWidget,
      );
      expect(find.byType(DebtSheetFrame), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
