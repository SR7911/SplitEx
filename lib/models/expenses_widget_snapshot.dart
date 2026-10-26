import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';

/// Matches My Expenses: all personal income and expense entries in the month.
/// Category budgets are intentionally separate from the income-based balance.
class ExpensesWidgetSnapshot {
  final String userId;
  final String monthKey;
  final int incomeMinor;
  final int expensesMinor;
  final int count;

  const ExpensesWidgetSnapshot({
    required this.userId,
    required this.monthKey,
    required this.incomeMinor,
    required this.expensesMinor,
    required this.count,
  });

  factory ExpensesWidgetSnapshot.fromTransactions({
    required String userId,
    required String monthKey,
    required List<PersonalTransactionModel> transactions,
  }) {
    var income = 0;
    var expenses = 0;
    var count = 0;
    for (final entry in transactions) {
      // Reject retained data belonging to a previous account or month.
      if (entry.userId != userId || entry.month != monthKey) continue;
      if (!entry.amount.isFinite || entry.amount < 0) {
        throw const FormatException('Invalid transaction amount');
      }
      final minor = (entry.amount * 100).round();
      if (entry.isExpense) {
        expenses += minor;
        count++;
      } else {
        income += minor;
      }
    }
    return ExpensesWidgetSnapshot(
      userId: userId,
      monthKey: monthKey,
      incomeMinor: income,
      expensesMinor: expenses,
      count: count,
    );
  }

  int get balanceMinor => incomeMinor - expensesMinor;
  int get progress => incomeMinor > 0
      ? (expensesMinor / incomeMinor * 100).clamp(0, 100).round()
      : 0;

  Map<String, Object> toPayload() {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 2,
    );
    final wholeMoney = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
    return {
      'schemaVersion': 2,
      'userId': userId,
      'monthKey': monthKey,
      'spent': money.format(expensesMinor / 100),
      'income': money.format(incomeMinor / 100),
      'balance': money.format(balanceMinor.abs() / 100),
      'spentWhole': wholeMoney.format(expensesMinor / 100),
      'incomeWhole': wholeMoney.format(incomeMinor / 100),
      'balanceWhole': wholeMoney.format(balanceMinor.abs() / 100),
      'balanceLabel': balanceMinor < 0 ? 'OVER INCOME' : 'BALANCE LEFT',
      'budget': incomeMinor > 0
          ? '${(expensesMinor / incomeMinor * 100).toStringAsFixed(1)}% of income spent'
          : 'No income recorded this month',
      'progress': progress,
      'hasIncome': incomeMinor > 0 ? 1 : 0,
      'overIncome': balanceMinor < 0 ? 1 : 0,
      'countLabel': '$count ${count == 1 ? 'expense' : 'expenses'}',
    };
  }
}
