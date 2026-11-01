import '../../entities/transactions/personal_transaction.dart';
import '../../entities/transactions/expense_split.dart';

/// Rules for a new Personal transaction before persistence checks run.
void validatePersonalTransactionForCreate(PersonalTransaction transaction) {
  if (!transaction.amount.isFinite || transaction.amount <= 0) {
    throw StateError('Enter a valid positive amount.');
  }
  moneyCents(transaction.amount);
  if (transaction.split != null) {
    if (transaction.type != TransactionType.expense || transaction.hasDebt) {
      throw StateError('Only a regular expense can be split.');
    }
    transaction.split!.validate(transaction.amount);
  }
  final dueDate = transaction.dueDate;
  if (dueDate != null &&
      DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(
        DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        ),
      )) {
    throw StateError('Repayment date cannot be before the debt date.');
  }
}
