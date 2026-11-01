import '../../entities/transactions/personal_transaction.dart';

class PersonalMonthlySummary {
  final double income;
  final double expenses;
  final double cashIncome;
  final double cashExpenses;

  const PersonalMonthlySummary({
    required this.income,
    required this.expenses,
    required this.cashIncome,
    required this.cashExpenses,
  });

  double get remaining => income - expenses;
  double get budgetUsage => income > 0 ? expenses / income : 0;
  double get cashMovement => cashIncome - cashExpenses;
}

PersonalMonthlySummary calculatePersonalMonthlySummary(
  Iterable<PersonalTransaction> transactions, {
  Iterable<PersonalTransaction> debts = const [],
  String? month,
}) {
  var income = 0.0;
  var expenses = 0.0;
  var cashIncome = 0.0;
  var cashExpenses = 0.0;
  for (final transaction in transactions) {
    // A split share is a receivable derived from its original expense, not
    // another transfer of cash. The original expense remains in this stream.
    if (transaction.splitSourceId != null) continue;
    if (transaction.isIncome) {
      cashIncome += transaction.amount;
    } else {
      cashExpenses += transaction.amount;
    }
    if (transaction.countsAsIncome) {
      income += transaction.amount;
    } else if (transaction.countsAsSpending) {
      expenses += transaction.amount;
    }
  }
  for (final debt in debts) {
    for (final settlement in debt.settlements) {
      final date = settlement.date;
      if (!settlement.isCashEntry ||
          settlement.isTally ||
          settlement.isWriteOff ||
          date == null ||
          month == null ||
          '${date.year}-${date.month.toString().padLeft(2, '0')}' != month) {
        continue;
      }
      if (debt.debtType == DebtType.lent) {
        cashIncome += settlement.amount;
      } else {
        cashExpenses += settlement.amount;
      }
    }
  }
  return PersonalMonthlySummary(
    income: income,
    expenses: expenses,
    cashIncome: cashIncome,
    cashExpenses: cashExpenses,
  );
}

Map<String, double> calculatePersonalCategorySpending(
  Iterable<PersonalTransaction> transactions,
) {
  final spending = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.countsAsSpending) {
      spending[transaction.category] =
          (spending[transaction.category] ?? 0) + transaction.amount;
    }
  }
  return spending;
}
