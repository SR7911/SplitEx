import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/group_model.dart';
import 'package:split_ex/models/group_expense_model.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/balance_service.dart';
import 'package:split_ex/services/group_service.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());
final groupExpenseServiceProvider = Provider<GroupExpenseService>((ref) => GroupExpenseService());
final groupBalanceServiceProvider = Provider<GroupBalanceService>((ref) => GroupBalanceService());

final userGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(groupServiceProvider).getUserGroupsStream(uid);
});

final groupStreamProvider = StreamProvider.family<GroupModel?, String>((ref, groupId) {
  return ref.watch(groupServiceProvider).getGroupStream(groupId);
});

final groupExpensesProvider = StreamProvider.family<List<GroupExpenseModel>, String>((ref, groupId) {
  return ref.watch(groupExpenseServiceProvider).getExpensesStream(groupId);
});

final groupNetBalancesProvider = Provider.family<Map<String, double>, String>((ref, groupId) {
  final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
  final group = ref.watch(groupStreamProvider(groupId)).valueOrNull;
  final memberIds = group?.memberIds ?? [];
  return ref.watch(groupBalanceServiceProvider).computeNetBalances(
        expenses: expenses,
        memberIds: memberIds,
      );
});

final groupSimplifiedDebtsProvider = Provider.family<List<Debt>, String>((ref, groupId) {
  final balances = ref.watch(groupNetBalancesProvider(groupId));
  return ref.watch(groupBalanceServiceProvider).simplifyDebts(balances);
});

final groupUserBalanceProvider = Provider.family<double, String>((ref, groupId) {
  final balances = ref.watch(groupNetBalancesProvider(groupId));
  final uid = ref.watch(currentUserIdProvider);
  return balances[uid] ?? 0;
});

final groupTotalExpenseProvider = Provider.family<double, String>((ref, groupId) {
  final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});
