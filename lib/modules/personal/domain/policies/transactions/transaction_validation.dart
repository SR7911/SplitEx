import '../../entities/transactions/personal_transaction.dart';

/// Rules for a new Personal transaction before persistence checks run.
void validatePersonalTransactionForCreate(PersonalTransaction transaction) {
  if (!transaction.amount.isFinite || transaction.amount <= 0) {
    throw StateError('Enter a valid positive amount.');
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
