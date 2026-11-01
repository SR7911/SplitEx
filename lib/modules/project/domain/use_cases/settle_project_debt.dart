import '../repositories/project_expense_repository.dart';

class SettleProjectDebt {
  final ProjectExpenseRepository expenses;
  const SettleProjectDebt(this.expenses);

  Future<void> call(String uid, String projectId, String expenseId) =>
      expenses.settleExpense(uid, projectId, expenseId);
}
