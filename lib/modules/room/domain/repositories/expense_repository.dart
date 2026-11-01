import '../entities/expense_model.dart';
import '../entities/room_expense_update.dart';

abstract interface class ExpenseRepository {
  Future<ExpenseModel> addExpense(String roomId, ExpenseModel expense);
  Future<void> updateExpense(
    String roomId,
    String expenseId,
    RoomExpenseUpdate changes,
  );
  Future<void> deleteExpense(String roomId, String expenseId);
  Stream<List<ExpenseModel>> getExpensesStream(String roomId, String month);
  Stream<List<ExpenseModel>> getAllExpensesStream(String roomId);
}
