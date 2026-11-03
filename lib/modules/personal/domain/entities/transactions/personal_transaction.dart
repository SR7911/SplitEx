import 'expense_split.dart';

enum TransactionType { expense, income }

enum DebtType { lent, borrowed }

/// A recorded payment or write-off against a personal debt.
class DebtSettlement {
  final double amount;
  final DateTime? date;
  final String note;
  final bool isWriteOff;
  final bool isTally;

  /// New settlements stored on the debt itself instead of a payment transaction.
  final bool isCashEntry;
  final String? repaymentId;
  final String? accountId;
  final String? bankSmsReceiptId;

  const DebtSettlement({
    required this.amount,
    required this.date,
    required this.note,
    required this.isWriteOff,
    this.isTally = false,
    this.isCashEntry = false,
    this.repaymentId,
    this.accountId,
    this.bankSmsReceiptId,
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
  final ExpenseSplit? split;
  final String? splitSourceId;
  final String? debtSourceId;

  /// Read-only live debt records for this expense's split shares; never persisted.
  final List<PersonalTransaction> linkedSplitDebts;

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
    this.split,
    this.splitSourceId,
    this.debtSourceId,
    this.linkedSplitDebts = const [],
  });

  bool get hasDebt =>
      debtType != null && personName != null && personName!.isNotEmpty;
  double get remainingAmount =>
      (amount - settledAmount - writtenOffAmount).clamp(0.0, double.infinity);
  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
  bool get isDebtCashFlow =>
      debtType != null || debtSourceId != null || splitSourceId != null;
  bool get countsAsSpending => isExpense && !isDebtCashFlow;
  bool get countsAsIncome => isIncome && !isDebtCashFlow;

  bool get hasSharedExpense => split?.shares.isNotEmpty == true;
  PersonalTransaction? debtForShare(ExpenseSplitShare share) => linkedSplitDebts
      .where((debt) => debt.id == share.debtId && debt.splitSourceId == id)
      .firstOrNull;
  bool get sharedStatusKnown =>
      hasSharedExpense &&
      split!.shares.every((share) => debtForShare(share) != null);
  double get sharedAmount =>
      (split?.shares ?? const <ExpenseSplitShare>[]).fold<int>(
        0,
        (sum, share) => sum + roundedMoneyCents(share.amount),
      ) /
      100;
  double get sharedRepaidAmount {
    var recovered = 0;
    for (final share in split?.shares ?? const <ExpenseSplitShare>[]) {
      final debt = debtForShare(share);
      if (debt == null) continue;
      final tally = debt.settlements
          .where((entry) => entry.isTally)
          .fold<double>(0, (sum, entry) => sum + entry.amount);
      recovered += ((debt.settledAmount - tally) * 100).round().clamp(
        0,
        roundedMoneyCents(share.amount),
      );
    }
    return recovered / 100;
  }

  double get sharedRemainingAmount =>
      (split?.shares ?? const <ExpenseSplitShare>[]).fold<int>(
        0,
        (sum, share) =>
            sum +
            roundedMoneyCents(
              debtForShare(share)?.remainingAmount ?? share.amount,
            ),
      ) /
      100;
  String get sharedStatus {
    if (!sharedStatusKnown) return 'Status unavailable';
    if (sharedRemainingAmount == 0) {
      return sharedRepaidAmount == sharedAmount ? 'Settled' : 'Closed';
    }
    return sharedRepaidAmount > 0 || sharedRemainingAmount < sharedAmount
        ? 'Partially settled'
        : 'Pending';
  }

  /// Reimbursements reduce the original purchase's net cost, not its cash debit.
  double get spendingAmount {
    if (!countsAsSpending) return 0;
    // Ordinary stored amounts may come from older imports or calculated EMIs.
    // Preserve their existing arithmetic; entry validation belongs on writes.
    if (!hasSharedExpense) return amount;
    final total = roundedMoneyCents(amount);
    return (total - roundedMoneyCents(sharedRepaidAmount)).clamp(0, total) /
        100;
  }

  PersonalTransaction withSplitDebts(List<PersonalTransaction> debts) =>
      PersonalTransaction(
        id: id,
        title: title,
        amount: amount,
        type: type,
        category: category,
        date: date,
        userId: userId,
        month: month,
        createdAt: createdAt,
        notes: notes,
        accountId: accountId,
        dueDate: dueDate,
        debtType: debtType,
        personName: personName,
        isSettled: isSettled,
        settledAmount: settledAmount,
        writtenOffAmount: writtenOffAmount,
        settlements: settlements,
        split: split,
        splitSourceId: splitSourceId,
        debtSourceId: debtSourceId,
        linkedSplitDebts: List.unmodifiable(debts),
      );
}
