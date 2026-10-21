import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';

class CategoryReview {
  final String category;
  final double current, previous;
  const CategoryReview(this.category, this.current, this.previous);
  double get difference => current - previous;
  double? get percent => previous > 0 ? difference / previous * 100 : null;
}

class BudgetReview {
  final CategoryBudget budget;
  final double spent;
  const BudgetReview(this.budget, this.spent);
  double get remaining => budget.budget - spent;
}

class MonthlyMoneyReview {
  final DateTime month, currentEnd, previousEnd;
  final bool inProgress;
  final double income, expenses, previousExpenses;
  final List<CategoryReview> categories;
  final List<BudgetReview> budgets;
  final List<PersonalTransactionModel> uncategorized;
  final double toReceiveNow, toRepayNow;
  const MonthlyMoneyReview({
    required this.month,
    required this.currentEnd,
    required this.previousEnd,
    required this.inProgress,
    required this.income,
    required this.expenses,
    required this.previousExpenses,
    required this.categories,
    required this.budgets,
    required this.uncategorized,
    required this.toReceiveNow,
    required this.toRepayNow,
  });
  double get difference => expenses - previousExpenses;
  double? get percent =>
      previousExpenses > 0 ? difference / previousExpenses * 100 : null;
  String get comparisonLabel => inProgress
      ? 'Compared with 1–${previousEnd.day} ${DateFormat('MMM').format(previousEnd)}'
      : 'Compared with ${DateFormat('MMMM').format(previousEnd)}';

  factory MonthlyMoneyReview.build({
    required DateTime month,
    required DateTime now,
    required List<PersonalTransactionModel> current,
    required List<PersonalTransactionModel> previous,
    required List<CategoryBudget> budgets,
    required List<PersonalTransactionModel> debts,
  }) {
    final start = DateTime(month.year, month.month);
    final before = DateTime(start.year, start.month - 1);
    final inProgress = start.year == now.year && start.month == now.month;
    final end = inProgress
        ? DateTime(now.year, now.month, now.day)
        : DateTime(start.year, start.month + 1, 0);
    final prevLast = DateTime(start.year, start.month, 0);
    final prevEnd = inProgress
        ? DateTime(before.year, before.month, now.day.clamp(1, prevLast.day))
        : prevLast;
    bool included(PersonalTransactionModel t, DateTime min, DateTime max) =>
        !t.date.isBefore(min) &&
        t.date.isBefore(DateTime(max.year, max.month, max.day + 1));
    final entries = current.where((t) => included(t, start, end)).toList();
    final old = previous.where((t) => included(t, before, prevEnd)).toList();
    double sum(Iterable<PersonalTransactionModel> ts) =>
        ts.fold(0, (n, t) => n + t.amount);
    Map<String, double> spending(List<PersonalTransactionModel> ts) {
      final values = <String, double>{};
      for (final t in ts.where((t) => t.isExpense)) {
        values[t.category] = (values[t.category] ?? 0) + t.amount;
      }
      return values;
    }

    final currentCategories = spending(entries), oldCategories = spending(old);
    final comparisons =
        {...currentCategories.keys, ...oldCategories.keys}
            .map(
              (key) => CategoryReview(
                key,
                currentCategories[key] ?? 0,
                oldCategories[key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.current.compareTo(a.current));
    final budgetReviews =
        budgets
            .map((b) => BudgetReview(b, currentCategories[b.category] ?? 0))
            .toList()
          ..sort((a, b) => a.remaining.compareTo(b.remaining));
    return MonthlyMoneyReview(
      month: start,
      currentEnd: end,
      previousEnd: prevEnd,
      inProgress: inProgress,
      income: sum(entries.where((t) => t.isIncome)),
      expenses: sum(entries.where((t) => t.isExpense)),
      previousExpenses: sum(old.where((t) => t.isExpense)),
      categories: comparisons,
      budgets: budgetReviews,
      uncategorized: entries
          .where(
            (t) =>
                t.isExpense &&
                (t.category.trim().isEmpty ||
                    t.category.toLowerCase() == 'other'),
          )
          .toList(),
      toReceiveNow: debts
          .where((t) => !t.isSettled && t.debtType == DebtType.lent)
          .fold(0, (n, t) => n + t.remainingAmount),
      toRepayNow: debts
          .where((t) => !t.isSettled && t.debtType == DebtType.borrowed)
          .fold(0, (n, t) => n + t.remainingAmount),
    );
  }
}
