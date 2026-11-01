import '../entities/group_expense_model.dart';
import '../entities/group_expense_update.dart';
import '../repositories/group_expense_repository.dart';

class SaveGroupExpense {
  final GroupExpenseRepository expenses;
  const SaveGroupExpense(this.expenses);

  Future<void> call({
    required String groupId,
    required String userId,
    required GroupExpenseUpdate changes,
    GroupExpenseModel? existing,
  }) async {
    if (existing != null) {
      await expenses.updateExpense(groupId, existing.id, changes);
      return;
    }
    await expenses.addExpense(
      GroupExpenseModel(
        id: '',
        groupId: groupId,
        title: changes.title,
        amount: changes.amount,
        category: changes.category,
        notes: changes.notes,
        paidBy: changes.paidBy,
        splitType: changes.splitType,
        splitAmong: changes.splitAmong,
        customSplits: changes.customSplits,
        date: changes.date,
        createdBy: userId,
        createdAt: DateTime.now(),
      ),
    );
  }
}
