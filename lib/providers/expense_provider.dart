import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/services/expense_service.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) => ExpenseService());

final currentMonthProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM').format(DateTime.now());
});

final expensesStreamProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, roomId) {
  final month = ref.watch(currentMonthProvider);
  return ref.watch(expenseServiceProvider).getExpensesStream(roomId, month);
});

final allExpensesStreamProvider =
    StreamProvider.family<List<ExpenseModel>, String>((ref, roomId) {
  return ref.watch(expenseServiceProvider).getAllExpensesStream(roomId);
});

/// Key for month-specific expense queries.
class MonthRoomKey {
  final String roomId;
  final String month;
  const MonthRoomKey({required this.roomId, required this.month});

  @override
  bool operator ==(Object other) =>
      other is MonthRoomKey && roomId == other.roomId && month == other.month;

  @override
  int get hashCode => Object.hash(roomId, month);
}

final monthExpensesProvider =
    StreamProvider.family<List<ExpenseModel>, MonthRoomKey>((ref, key) {
  return ref
      .watch(expenseServiceProvider)
      .getExpensesStream(key.roomId, key.month);
});
