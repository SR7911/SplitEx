import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/shared/domain/entities/debt.dart';
import 'package:split_ex/shared/domain/policies/debt_simplifier.dart';

export 'package:split_ex/shared/domain/entities/debt.dart' show Debt;

class BalanceService {
  /// Computes net balance for each user. Positive = owed money, Negative = owes money.
  Map<String, double> computeNetBalances({
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required List<String> memberIds,
  }) {
    final balances = <String, double>{};

    // Initialize balances for all members to 0
    for (final id in memberIds) {
      balances[id] = 0;
    }

    // Process Expenses
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

    // Process Bills (Shared equally among all members)
    for (final bill in bills) {
      final payer = bill.paidBy;
      if (memberIds.isEmpty) continue;

      final share = bill.amount / memberIds.length;

      // Payer is owed by others
      balances[payer] = (balances[payer] ?? 0) + bill.amount;

      // Each member owes their share
      for (final member in memberIds) {
        balances[member] = (balances[member] ?? 0) - share;
      }
    }

    return balances;
  }

  /// Simplifies debts into minimum transactions using greedy algorithm.
  List<Debt> simplifyDebts(Map<String, double> netBalances) =>
      simplifyNetBalances(netBalances);

  /// Get what a specific user owes or is owed.
  double getUserBalance(Map<String, double> netBalances, String userId) {
    return netBalances[userId] ?? 0;
  }

  /// Get debts involving a specific user.
  List<Debt> getUserDebts(List<Debt> allDebts, String userId) {
    return allDebts.where((d) => d.from == userId || d.to == userId).toList();
  }
}
