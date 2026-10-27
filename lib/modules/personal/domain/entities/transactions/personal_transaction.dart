enum TransactionType { expense, income }

enum DebtType { lent, borrowed }

/// A recorded payment or write-off against a personal debt.
class DebtSettlement {
  final double amount;
  final DateTime? date;
  final String note;
  final bool isWriteOff;

  const DebtSettlement({
    required this.amount,
    required this.date,
    required this.note,
    required this.isWriteOff,
  });
}

/// Business value shared by account balances and transaction details.
/// Persistence metadata/history is decoded by data adapters, not this entity.
class PersonalTransaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? notes;
  final String userId;
  final String month;
  final DateTime createdAt;
  final String? accountId;
  final DateTime? dueDate;
  final DebtType? debtType;
  final String? personName;
  final bool isSettled;
  final double settledAmount;
  final double writtenOffAmount;
  final List<DebtSettlement> settlements;

  const PersonalTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.userId,
    required this.month,
    required this.createdAt,
    this.notes,
    this.accountId,
    this.dueDate,
    this.debtType,
    this.personName,
    this.isSettled = false,
    this.settledAmount = 0,
    this.writtenOffAmount = 0,
    this.settlements = const [],
  });

  bool get hasDebt =>
      debtType != null && personName != null && personName!.isNotEmpty;
  double get remainingAmount =>
      (amount - settledAmount - writtenOffAmount).clamp(0.0, double.infinity);
  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
}
