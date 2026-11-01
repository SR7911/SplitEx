import '../entities/debt.dart';

/// Simplifies net balances using the existing greedy settlement order.
List<Debt> simplifyNetBalances(Map<String, double> netBalances) {
  final creditors = <MapEntry<String, double>>[];
  final debtors = <MapEntry<String, double>>[];

  for (final entry in netBalances.entries) {
    if (entry.value > 0.01) {
      creditors.add(entry);
    } else if (entry.value < -0.01) {
      debtors.add(entry);
    }
  }

  creditors.sort((a, b) => b.value.compareTo(a.value));
  debtors.sort((a, b) => a.value.compareTo(b.value));

  final debts = <Debt>[];
  var i = 0, j = 0;

  final creds = creditors.map((e) => MapEntry(e.key, e.value)).toList();
  final debts_ = debtors.map((e) => MapEntry(e.key, -e.value)).toList();

  while (i < creds.length && j < debts_.length) {
    final amount = creds[i].value < debts_[j].value
        ? creds[i].value
        : debts_[j].value;

    debts.add(Debt(from: debts_[j].key, to: creds[i].key, amount: amount));

    creds[i] = MapEntry(creds[i].key, creds[i].value - amount);
    debts_[j] = MapEntry(debts_[j].key, debts_[j].value - amount);

    if (creds[i].value < 0.01) i++;
    if (debts_[j].value < 0.01) j++;
  }

  return debts;
}
