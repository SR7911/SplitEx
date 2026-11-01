import '../entities/group_expense_model.dart';
import '../entities/group_expense_update.dart';

abstract interface class GroupExpenseRepository {
  Future<GroupExpenseModel> addExpense(GroupExpenseModel expense);
  Future<void> updateExpense(
    String groupId,
    String expenseId,
    GroupExpenseUpdate changes,
  );
  Future<void> deleteExpense(String groupId, String expenseId);
  Stream<List<GroupExpenseModel>> getExpensesStream(String groupId);
}
