import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/group/domain/entities/group_model.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_model.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import 'package:split_ex/shared/domain/entities/debt.dart';
import 'package:split_ex/modules/group/dependencies.dart';
import 'package:split_ex/modules/group/domain/policies/group_balance_calculator.dart';
export 'package:split_ex/modules/group/dependencies.dart'
    show
        groupServiceProvider,
        groupFirestoreExpenseRepositoryProvider,
        groupFirestoreSettlementRepositoryProvider;
import 'package:split_ex/app/auth/providers/session_provider.dart';

final groupSettlementsProvider =
    StreamProvider.family<List<SettlementModel>, String>((ref, groupId) {
      return ref
          .watch(groupFirestoreSettlementRepositoryProvider)
          .getSettlementsStream(groupId);
    });

final groupBalanceCalculatorProvider = Provider<GroupBalanceCalculator>(
  (ref) => GroupBalanceCalculator(),
);

final userGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(groupServiceProvider).getUserGroupsStream(uid);
});

final groupStreamProvider = StreamProvider.family<GroupModel?, String>((
  ref,
  groupId,
) {
  return ref.watch(groupServiceProvider).getGroupStream(groupId);
});

final groupExpensesProvider =
    StreamProvider.family<List<GroupExpenseModel>, String>((ref, groupId) {
      return ref.watch(groupFirestoreExpenseRepositoryProvider).getExpensesStream(groupId);
    });

final groupNetBalancesProvider = Provider.family<Map<String, double>, String>((
  ref,
  groupId,
) {
  final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
  final group = ref.watch(groupStreamProvider(groupId)).valueOrNull;
  final memberIds = group?.memberIds ?? [];
  return ref
      .watch(groupBalanceCalculatorProvider)
      .computeNetBalances(expenses: expenses, memberIds: memberIds);
});

final groupSimplifiedDebtsProvider = Provider.family<List<Debt>, String>((
  ref,
  groupId,
) {
  final balances = ref.watch(groupNetBalancesProvider(groupId));
  return ref.watch(groupBalanceCalculatorProvider).simplifyDebts(balances);
});

final groupUserBalanceProvider = Provider.family<double, String>((
  ref,
  groupId,
) {
  final balances = ref.watch(groupNetBalancesProvider(groupId));
  final uid = ref.watch(currentUserIdProvider);
  return balances[uid] ?? 0;
});

final groupTotalExpenseProvider = Provider.family<double, String>((
  ref,
  groupId,
) {
  final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});

/// Month key 'yyyy-MM' -> total spent
final groupMonthlySpendingProvider =
    Provider.family<Map<String, double>, String>((ref, groupId) {
      final expenses =
          ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
      final map = <String, double>{};
      for (final e in expenses) {
        final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
        map[key] = (map[key] ?? 0) + e.amount;
      }
      return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    });

/// Category -> total spent
final groupCategoryBreakdownProvider =
    Provider.family<Map<String, double>, String>((ref, groupId) {
      final expenses =
          ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
      final map = <String, double>{};
      for (final e in expenses) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
      return map;
    });

/// Split type name -> count
final groupSplitTypeBreakdownProvider =
    Provider.family<Map<String, int>, String>((ref, groupId) {
      final expenses =
          ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
      final map = <String, int>{};
      for (final e in expenses) {
        map[e.splitType.name] = (map[e.splitType.name] ?? 0) + 1;
      }
      return map;
    });
