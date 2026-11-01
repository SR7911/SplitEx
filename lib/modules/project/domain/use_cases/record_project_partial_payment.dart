import '../repositories/project_expense_repository.dart';

class RecordProjectPartialPayment {
  final ProjectExpenseRepository expenses;
  const RecordProjectPartialPayment(this.expenses);

  Future<void> call(
    String uid,
    String projectId,
    String expenseId,
    double amount,
    String? note,
  ) {
    if (amount <= 0 || !amount.isFinite) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Payment must be positive and finite.',
      );
    }
    return expenses.partialSettleExpense(
      uid,
      projectId,
      expenseId,
      amount,
      note,
    );
  }
}
