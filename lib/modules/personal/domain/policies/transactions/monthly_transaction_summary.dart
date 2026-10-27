import '../../entities/transactions/personal_transaction.dart';

class PersonalMonthlySummary {
  final double income;
  final double expenses;

  const PersonalMonthlySummary({required this.income, required this.expenses});

  double get remaining => income - expenses;
  double get budgetUsage => income > 0 ? expenses / income : 0;
}

PersonalMonthlySummary calculatePersonalMonthlySummary(
  Iterable<PersonalTransaction> transactions,
) {
  var income = 0.0;
  var expenses = 0.0;
  for (final transaction in transactions) {
    if (transaction.isIncome) {
      income += transaction.amount;
    } else {
      expenses += transaction.amount;
    }
  }
  return PersonalMonthlySummary(income: income, expenses: expenses);
}

Map<String, double> calculatePersonalCategorySpending(
  Iterable<PersonalTransaction> transactions,
) {
  final spending = <String, double>{};
  for (final transaction in transactions) {
    if (transaction.isExpense) {
      spending[transaction.category] =
          (spending[transaction.category] ?? 0) + transaction.amount;
    }
  }
  return spending;
}
