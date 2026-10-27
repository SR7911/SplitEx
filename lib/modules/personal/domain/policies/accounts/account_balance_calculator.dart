import '../../entities/accounts/personal_account.dart';
import '../../entities/accounts/personal_transfer.dart';
import '../../entities/transactions/personal_transaction.dart';

Map<String, double> calculateAccountBalances(
  List<PersonalAccount> accounts,
  List<PersonalTransaction> transactions,
  List<PersonalTransfer> transfers,
) {
  // Recompute from records: edits, deletions and retries cannot drift balances.
  // Preserve the existing per-record rounding to integer paise.
  final balances = {
    for (final account in accounts)
      account.id: (account.openingBalance * 100).round(),
  };
  for (final entry in transactions) {
    if (balances.containsKey(entry.accountId)) {
      final value = (entry.amount * 100).round();
      balances[entry.accountId!] =
          balances[entry.accountId!]! + (entry.isIncome ? value : -value);
    }
  }
  for (final transfer in transfers) {
    final value = (transfer.amount * 100).round();
    if (balances.containsKey(transfer.fromAccountId)) {
      balances[transfer.fromAccountId] =
          balances[transfer.fromAccountId]! - value;
    }
    if (balances.containsKey(transfer.toAccountId)) {
      balances[transfer.toAccountId] = balances[transfer.toAccountId]! + value;
    }
  }
  return balances.map((key, value) => MapEntry(key, value / 100));
}
