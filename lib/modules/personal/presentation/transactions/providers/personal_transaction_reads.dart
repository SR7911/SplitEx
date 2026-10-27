import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';

final personalMonthTransactionsProvider =
    StreamProvider.family<List<PersonalTransaction>, String>((ref, month) {
      final userId = ref.watch(personalUserIdProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);
      return ref
          .watch(personalTransactionRepositoryProvider)
          .transactionsForMonth(userId, month);
    });

final personalDebtTransactionsProvider =
    StreamProvider<List<PersonalTransaction>>((ref) {
      final userId = ref.watch(personalUserIdProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);
      return ref.watch(personalTransactionRepositoryProvider).debts(userId);
    });

final personalDebtsForMonthProvider =
    Provider.family<List<PersonalTransaction>, String>((ref, month) {
      final debts =
          ref.watch(personalDebtTransactionsProvider).valueOrNull ?? [];
      return debts.where((transaction) => transaction.month == month).toList();
    });

final personalDebtBalancesProvider = Provider<Map<String, double>>((ref) {
  final debts = ref.watch(personalDebtTransactionsProvider).valueOrNull ?? [];
  final balances = <String, double>{};
  for (final debt in debts) {
    final person = debt.personName;
    if (person == null || debt.isSettled) continue;
    if (debt.debtType == DebtType.lent) {
      balances[person] = (balances[person] ?? 0) + debt.remainingAmount;
    } else {
      balances[person] = (balances[person] ?? 0) - debt.remainingAmount;
    }
  }
  return balances;
});

final debtPersonSuggestionsProvider = Provider<List<String>>((ref) {
  final debts = ref.watch(personalDebtTransactionsProvider).valueOrNull ?? [];
  final names = <String>{};
  for (final debt in debts) {
    if (debt.personName != null && debt.personName!.isNotEmpty) {
      names.add(debt.personName!);
    }
  }
  return names.toList()..sort();
});

final personalDomainMonthlySummaryProvider =
    Provider.family<PersonalMonthlySummary, String>((ref, month) {
      final transactions =
          ref.watch(personalMonthTransactionsProvider(month)).valueOrNull ?? [];
      return calculatePersonalMonthlySummary(transactions);
    });

final personalDomainCategorySpendingProvider =
    Provider.family<Map<String, double>, String>((ref, month) {
      final transactions =
          ref.watch(personalMonthTransactionsProvider(month)).valueOrNull ?? [];
      return calculatePersonalCategorySpending(transactions);
    });
