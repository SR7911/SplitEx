import 'package:split_ex/modules/group/domain/entities/group_expense_model.dart';
import 'package:split_ex/shared/domain/entities/debt.dart';
import 'package:split_ex/shared/domain/policies/debt_simplifier.dart';

class GroupBalanceCalculator {
  Map<String, double> computeNetBalances({
    required List<GroupExpenseModel> expenses,
    required List<String> memberIds,
  }) {
    final balances = {for (final id in memberIds) id: 0.0};
    for (final expense in expenses) {
      final payer = expense.paidBy;
      final splitAmong = expense.splitAmong;
      if (splitAmong.isEmpty) continue;

      balances[payer] = (balances[payer] ?? 0) + expense.amount;
      for (final member in splitAmong) {
        balances[member] = (balances[member] ?? 0) - expense.shareFor(member);
      }
    }
    return balances;
  }

  List<Debt> simplifyDebts(Map<String, double> netBalances) =>
      simplifyNetBalances(netBalances);
}
