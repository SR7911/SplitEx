import '../../entities/transactions/personal_transaction.dart';

/// Join once per stream update; presentation and spending share the same state.
List<PersonalTransaction> attachSharedExpenseDebts(
  Iterable<PersonalTransaction> transactions,
  Iterable<PersonalTransaction> debts,
) {
  final byParent = <String, List<PersonalTransaction>>{};
  for (final debt in debts) {
    if (debt.splitSourceId != null && debt.debtType == DebtType.lent) {
      byParent.putIfAbsent(debt.splitSourceId!, () => []).add(debt);
    }
  }
  return [
    for (final transaction in transactions)
      if (transaction.hasSharedExpense && byParent.containsKey(transaction.id))
        transaction.withSplitDebts(
          byParent[transaction.id]!
              .where((debt) => debt.userId == transaction.userId)
              .toList(),
        )
      else
        transaction,
  ];
}
