import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/screens/personal_expense_tab.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/widgets/personal_needs_attention_card.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_controller.dart';
import 'package:split_ex/modules/personal/data/datasources/method_channel_bank_sms_data_source.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/shared/ui/theme.dart';

void main() {
  testWidgets('dashboard section headers with actions have bounded width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Gilmer',
    )..addFont(rootBundle.load('assets/fonts/Gilmer-Regular.otf'))).load();

    final now = DateTime.now();
    final transaction = PersonalTransaction(
      id: 'lunch',
      title: 'Lunch',
      amount: 250 / 3, // Legacy/calculated amounts can contain extra precision.
      type: TransactionType.expense,
      category: 'Food',
      date: now,
      userId: 'test-user',
      month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      createdAt: now,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalUserIdProvider.overrideWithValue(const AsyncData(null)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          personalMonthTransactionsProvider.overrideWith(
            (ref, month) => Stream.value([transaction]),
          ),
          bankSmsControllerProvider.overrideWith(
            (ref) =>
                BankSmsController(device: MethodChannelBankSmsDataSource())
                  ..statusLoaded = true,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppPalette.teal),
          home: const Scaffold(body: PersonalExpenseTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byType(PersonalNeedsAttentionCard)).dy -
          tester.getBottomRight(find.byType(PersonalFinancialStatusCard)).dy,
      16,
    );

    for (final title in ['Weekly Spending', 'Recent Transactions', 'Debts']) {
      await tester.scrollUntilVisible(
        find.text(title),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('monthly hero shows the original balance and savings layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Gilmer',
    )..addFont(rootBundle.load('assets/fonts/Gilmer-Regular.otf'))).load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppPalette.teal),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PersonalFinancialStatusCard(
              summary: const PersonalMonthlySummary(
                income: 20000,
                expenses: 32500,
                cashIncome: 20000,
                cashExpenses: 35154,
              ),
              selectedMonth: DateTime(2026, 10),
              isCurrentMonth: false,
              onPrev: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Overspent By'), findsOneWidget);
    expect(find.text('₹12500'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('₹20000'), findsOneWidget);
    expect(find.text('₹32500'), findsOneWidget);
    expect(find.text('-62%'), findsOneWidget);
    expect(find.text('saved'), findsOneWidget);
    expect(find.text('100% of income spent'), findsOneWidget);
    expect(find.text('₹12500 over'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('income and expense cards do not repeat a deficit amount', (
    tester,
  ) async {
    const summary = PersonalMonthlySummary(
      income: 20000,
      expenses: 32500,
      cashIncome: 20000,
      cashExpenses: 35154,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => incomeExpensePills(context, summary),
          ),
        ),
      ),
    );

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Deficit'), findsNothing);
    expect(find.text('₹12500'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
