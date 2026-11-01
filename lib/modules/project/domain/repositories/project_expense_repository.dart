import '../entities/project_model.dart';
import '../entities/project_expense_update.dart';

abstract interface class ProjectExpenseRepository {
  Future<ProjectExpenseModel> addExpense(
    String uid,
    ProjectExpenseModel expense,
  );
  Future<void> updateExpense(
    String uid,
    String projectId,
    String expenseId,
    ProjectExpenseUpdate changes,
  );
  Future<void> deleteExpense(String uid, String projectId, String expenseId);
  Future<void> markExpenseSettled(
    String uid,
    String projectId,
    String expenseId,
  );
  Future<void> settleExpense(String uid, String projectId, String expenseId);
  Future<void> partialSettleExpense(
    String uid,
    String projectId,
    String expenseId,
    double partialAmount,
    String? note,
  );
  Stream<List<ProjectExpenseModel>> getExpensesStream(
    String uid,
    String projectId,
  );
}
