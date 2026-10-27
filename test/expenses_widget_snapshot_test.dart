import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/settings/models/expenses_widget_snapshot.dart';
import 'support/personal_transaction_fixture.dart';

void main() {
  PersonalTransactionModel entry(
    double amount, {
    TransactionType type = TransactionType.expense,
    String user = 'me',
    String month = '2026-10',
  }) => PersonalTransactionModel(
    id: '$amount-$type',
    title: 'Entry',
    amount: amount,
    type: type,
    category: 'Food',
    date: DateTime(2026, 10, 23),
    userId: user,
    month: month,
    createdAt: DateTime(2026, 10, 23),
  );
  ExpensesWidgetSnapshot snapshot(List<PersonalTransactionModel> entries) =>
      ExpensesWidgetSnapshot.fromTransactions(
        userId: 'me',
        monthKey: '2026-10',
        transactions: entries,
      );

  test(
    'regression: 10k overspending is not presented as category budget remaining',
    () {
      final result = snapshot([
        entry(20000, type: TransactionType.income),
        entry(30000),
      ]);
      expect(result.balanceMinor, -1000000);
      expect(result.toPayload()['balanceLabel'], 'OVER INCOME');
      expect(result.toPayload()['balance'], '₹10,000.00');
      expect(result.toPayload()['budget'], '150.0% of income spent');
      expect(result.progress, 100);
    },
  );

  test('widget balance agrees with the My Expenses monthly summary', () async {
    final entries = [
      entry(20000.75, type: TransactionType.income),
      entry(25000.50), entry(5000.25),
    ];
    final container = ProviderContainer(overrides: [
      personalMonthTransactionsProvider('2026-10').overrideWith((ref) => Stream.value(entries)),
    ]);
    addTearDown(container.dispose);
    await container.read(personalMonthTransactionsProvider('2026-10').future);
    final app = container.read(personalDomainMonthlySummaryProvider('2026-10'));
    final widget = snapshot(entries);
    expect(widget.expensesMinor / 100, app.expenses);
    expect(widget.incomeMinor / 100, app.income);
    expect(widget.balanceMinor / 100, app.remaining);
    expect(widget.toPayload()['balanceLabel'], 'OVER INCOME');
  });

  test(
    'keeps paise and calculates positive balance without double rounding',
    () {
      final result = snapshot([
        entry(1000.50, type: TransactionType.income),
        entry(100.10),
        entry(200.20),
      ]);
      expect(result.expensesMinor, 30030);
      expect(result.balanceMinor, 70020);
      expect(result.toPayload()['spent'], '₹300.30');
      expect(result.toPayload()['balance'], '₹700.20');
      expect(result.toPayload()['balanceLabel'], 'BALANCE LEFT');
      expect(result.toPayload()['countLabel'], '2 expenses');
    },
  );

  test(
    'no income reports a shortfall without a fictitious budget or percentage',
    () {
      final result = snapshot([entry(500)]);
      expect(result.balanceMinor, -50000);
      expect(result.toPayload()['hasIncome'], 0);
      expect(result.toPayload()['budget'], 'No income recorded this month');
      expect(result.toPayload()['balanceLabel'], 'OVER INCOME');
    },
  );

  test('empty data is a real zero and not a loading placeholder', () {
    final result = snapshot([]);
    expect(result.toPayload()['spent'], '₹0.00');
    expect(result.toPayload()['countLabel'], '0 expenses');
    expect(result.balanceMinor, 0);
  });

  test('whole-rupee display rounds without changing the precise underlying balance', () {
    final result = snapshot([entry(100.99)]);
    expect(result.expensesMinor, 10099);
    expect(result.toPayload()['spent'], '₹100.99');
    expect(result.toPayload()['spentWhole'], '₹101');
  });

  test(
    'retained transactions for another account or month do not leak into totals',
    () {
      final result = snapshot([
        entry(10),
        entry(999, user: 'other'),
        entry(999, month: '2026-09'),
      ]);
      expect(result.expensesMinor, 1000);
      expect(result.count, 1);
    },
  );

  test(
    'invalid amounts produce an error rather than a plausible financial total',
    () {
      expect(() => snapshot([entry(double.nan)]), throwsFormatException);
      expect(() => snapshot([entry(double.infinity)]), throwsFormatException);
      expect(() => snapshot([entry(-100)]), throwsFormatException);
    },
  );
}
