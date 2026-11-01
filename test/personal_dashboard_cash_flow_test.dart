import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/screens/personal_expense_tab.dart';

void main() {
  testWidgets('monthly card shows money movement including debt cash flows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
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

    expect(find.text('More money went out than came in'), findsOneWidget);
    expect(find.text('₹15154'), findsOneWidget);
    expect(find.text('Money in'), findsOneWidget);
    expect(find.text('Money out'), findsOneWidget);
    expect(find.text('Includes money lent, borrowed, and repaid'), findsOneWidget);
    expect(find.textContaining('debt effect'), findsNothing);
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
