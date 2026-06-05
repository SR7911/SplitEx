import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/balance_service.dart';

final balanceServiceProvider = Provider<BalanceService>((ref) => BalanceService());

/// Key for month-specific balance queries.
class MonthBalanceKey {
  final String roomId;
  final String month; // 'yyyy-MM'
  const MonthBalanceKey({required this.roomId, required this.month});

  @override
  bool operator ==(Object other) =>
      other is MonthBalanceKey && roomId == other.roomId && month == other.month;

  @override
  int get hashCode => Object.hash(roomId, month);
}

final netBalancesProvider =
    Provider.family<Map<String, double>, String>((ref, roomId) {
  final expenses = ref.watch(expensesStreamProvider(roomId)).valueOrNull ?? [];
  return ref.watch(balanceServiceProvider).computeNetBalances(expenses);
});

/// Net balances for a room filtered by a specific month.
final monthNetBalancesProvider =
    Provider.family<Map<String, double>, MonthBalanceKey>((ref, key) {
  final expenses = ref.watch(monthExpensesProvider(
    MonthRoomKey(roomId: key.roomId, month: key.month),
  )).valueOrNull ?? [];
  return ref.watch(balanceServiceProvider).computeNetBalances(expenses);
});

/// Current user balance for a room in a specific month.
final monthUserBalanceProvider =
    Provider.family<double, MonthBalanceKey>((ref, key) {
  final balances = ref.watch(monthNetBalancesProvider(key));
  final userId = ref.watch(currentUserIdProvider);
  return balances[userId] ?? 0;
});

final simplifiedDebtsProvider =
    Provider.family<List<Debt>, String>((ref, roomId) {
  final balances = ref.watch(netBalancesProvider(roomId));
  return ref.watch(balanceServiceProvider).simplifyDebts(balances);
});

final currentUserBalanceProvider =
    Provider.family<double, String>((ref, roomId) {
  final balances = ref.watch(netBalancesProvider(roomId));
  final userId = ref.watch(currentUserIdProvider);
  return balances[userId] ?? 0;
});

final currentUserDebtsProvider =
    Provider.family<List<Debt>, String>((ref, roomId) {
  final debts = ref.watch(simplifiedDebtsProvider(roomId));
  final userId = ref.watch(currentUserIdProvider);
  return debts.where((d) => d.from == userId || d.to == userId).toList();
});

/// Overall balance across all rooms (current month).
final overallBalanceProvider = Provider<double>((ref) {
  final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
  double total = 0;
  for (final room in rooms) {
    total += ref.watch(currentUserBalanceProvider(room.id));
  }
  return total;
});

/// Overall balance across all rooms for a specific month.
final monthOverallBalanceProvider =
    Provider.family<double, String>((ref, month) {
  final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
  double total = 0;
  for (final room in rooms) {
    total += ref.watch(monthUserBalanceProvider(
      MonthBalanceKey(roomId: room.id, month: month),
    ));
  }
  return total;
});
