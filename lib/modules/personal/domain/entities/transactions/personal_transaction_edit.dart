import 'personal_transaction.dart';

/// Values supplied by the transaction editor. Nullable fields are cleared when null.
class PersonalTransactionEdit {
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? notes;
  final String? accountId;
  final DateTime? dueDate;
  final DebtType? debtType;
  final String? personName;
  final bool isSettled;

  const PersonalTransactionEdit({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.isSettled,
    this.notes,
    this.accountId,
    this.dueDate,
    this.debtType,
    this.personName,
  });
}
