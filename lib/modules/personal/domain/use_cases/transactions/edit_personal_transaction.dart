import '../../entities/transactions/personal_transaction_edit.dart';
import '../../entities/transactions/personal_transaction.dart';
import '../../entities/transactions/expense_split.dart';
import '../../repositories/personal_transaction_repository.dart';

class EditPersonalTransaction {
  final PersonalTransactionRepository _repository;
  const EditPersonalTransaction(this._repository);

  Future<void> call(
    String userId,
    String id,
    PersonalTransactionEdit edit,
  ) async {
    if (!edit.amount.isFinite || edit.amount <= 0) {
      throw StateError('Enter a valid positive amount.');
    }
    moneyCents(edit.amount);
    if (edit.split != null) {
      if (edit.type != TransactionType.expense || edit.debtType != null) {
        throw StateError('Only a regular expense can be split.');
      }
      edit.split!.validate(edit.amount);
    }
    final due = edit.dueDate;
    if (due != null &&
        DateTime(
          due.year,
          due.month,
          due.day,
        ).isBefore(DateTime(edit.date.year, edit.date.month, edit.date.day))) {
      throw StateError('Repayment date cannot be before the debt date.');
    }
    await _repository.update(userId, id, edit);
  }
}
