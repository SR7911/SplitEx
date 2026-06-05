import 'package:split_ex/models/expense_model.dart';

class Debt {
  final String from;
  final String to;
  final double amount;

  const Debt({required this.from, required this.to, required this.amount});
}

class BalanceService {
  /// Computes net balance for each user. Positive = owed money, Negative = owes money.
  Map<String, double> computeNetBalances(List<ExpenseModel> expenses) {
    final balances = <String, double>{};

    for (final expense in expenses) {
      final payer = expense.paidBy;
      final splitMembers = expense.splitAmong;
      if (splitMembers.isEmpty) continue;

      final share = expense.amount / splitMembers.length;

      // Payer is owed by others
      balances[payer] = (balances[payer] ?? 0) + expense.amount;

      // Each member owes their share
      for (final member in splitMembers) {
        balances[member] = (balances[member] ?? 0) - share;
      }
    }

    return balances;
  }

  /// Simplifies debts into minimum transactions using greedy algorithm.
  List<Debt> simplifyDebts(Map<String, double> netBalances) {
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

  /// Get what a specific user owes or is owed.
  double getUserBalance(Map<String, double> netBalances, String userId) {
    return netBalances[userId] ?? 0;
  }

  /// Get debts involving a specific user.
  List<Debt> getUserDebts(List<Debt> allDebts, String userId) {
    return allDebts.where((d) => d.from == userId || d.to == userId).toList();
  }
}
