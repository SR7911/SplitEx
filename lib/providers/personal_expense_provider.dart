import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/services/personal_expense_service.dart';

final personalExpenseServiceProvider =
    Provider<PersonalExpenseService>((ref) => PersonalExpenseService());

// ─── Transactions ───

final personalTransactionsProvider =
    StreamProvider.family<List<PersonalTransactionModel>, String>((ref, month) {
  final userId = ref.watch(authStateProvider).valueOrNull?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(personalExpenseServiceProvider).getTransactionsStream(userId, month);
});

// ─── Budgets ───

final personalBudgetsProvider =
    StreamProvider.family<List<CategoryBudget>, String>((ref, month) {
  final userId = ref.watch(authStateProvider).valueOrNull?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(personalExpenseServiceProvider).getBudgetsStream(userId, month);
});

// ─── Recurring ───

final personalRecurringProvider =
    StreamProvider<List<RecurringTransaction>>((ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(personalExpenseServiceProvider).getRecurringStream(userId);
});

// ─── Computed: Monthly Summary ───

final personalMonthlySummaryProvider =
    Provider.family<_MonthlySummary, String>((ref, month) {
  final txns = ref.watch(personalTransactionsProvider(month)).valueOrNull ?? [];
  double income = 0;
  double expenses = 0;
  for (final t in txns) {
    if (t.isIncome) {
      income += t.amount;
    } else {
      expenses += t.amount;
    }
  }
  return _MonthlySummary(income: income, expenses: expenses);
});

class _MonthlySummary {
  final double income;
  final double expenses;
  double get remaining => income - expenses;
  double get budgetUsage => income > 0 ? expenses / income : 0;
  const _MonthlySummary({required this.income, required this.expenses});
}

// ─── Computed: Category Spending ───

final personalCategorySpendingProvider =
    Provider.family<Map<String, double>, String>((ref, month) {
  final txns = ref.watch(personalTransactionsProvider(month)).valueOrNull ?? [];
  final map = <String, double>{};
  for (final t in txns) {
    if (t.isExpense) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
  }
  return map;
});
