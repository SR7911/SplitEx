import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';

void main() {
  PersonalTransaction entry(
    double amount,
    TransactionType type,
    String category,
  ) => PersonalTransaction(
    id: '$amount-$category',
    title: category,
    amount: amount,
    type: type,
    category: category,
    date: DateTime(2025, 8, 1),
    userId: 'user',
    month: '2025-08',
    createdAt: DateTime(2025, 8, 1),
  );

  test('monthly income, spending and categories match transaction values', () {
    final transactions = [
      entry(1000, TransactionType.income, 'Salary'),
      entry(125.5, TransactionType.expense, 'Food'),
      entry(24.5, TransactionType.expense, 'Food'),
      entry(50, TransactionType.expense, 'Transport'),
    ];
    final summary = calculatePersonalMonthlySummary(transactions);
    final spending = calculatePersonalCategorySpending(transactions);

    expect(summary.income, 1000);
    expect(summary.expenses, 200);
    expect(summary.remaining, 800);
    expect(summary.budgetUsage, .2);
    expect(spending, {'Food': 150, 'Transport': 50});
  });
}
