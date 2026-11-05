import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/shared/domain/entities/debt.dart';
import 'package:split_ex/shared/domain/policies/debt_simplifier.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

export 'package:split_ex/shared/domain/entities/debt.dart' show Debt;

class BalanceService {
  /// Computes net balance for each user. Positive = owed money, Negative = owes money.
  Map<String, double> computeNetBalances({
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required List<String> memberIds,
    List<SettlementModel> settlements = const [],
    List<String>? legacyBillMemberIds,
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
      final participants = bill.splitAmong.isNotEmpty
          ? bill.splitAmong
          : (legacyBillMemberIds ?? memberIds);
      if (participants.isEmpty) continue;

      final share = bill.amount / participants.length;

      // Payer is owed by others
      balances[payer] = (balances[payer] ?? 0) + bill.amount;

      // Each member owes their share
      for (final member in participants) {
        balances[member] = (balances[member] ?? 0) - share;
      }
    }

    for (final settlement in settlements) {
      if (settlement.status != SettlementStatus.confirmed) continue;
      balances[settlement.fromUserId] =
          (balances[settlement.fromUserId] ?? 0) + settlement.amount;
      balances[settlement.toUserId] =
          (balances[settlement.toUserId] ?? 0) - settlement.amount;
    }

    return balances;
  }

  /// Direct pair balance before settlements. Positive means [from] owes [to].
  double pairBalance({
    required String from,
    required String to,
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required List<String> legacyBillMemberIds,
  }) {
    double total = 0;
    void add(String payer, double amount, List<String> participants) {
      if (participants.isEmpty) return;
      if (payer == to && participants.contains(from))
        total += amount / participants.length;
      if (payer == from && participants.contains(to))
        total -= amount / participants.length;
    }

    for (final expense in expenses) {
      add(expense.paidBy, expense.amount, expense.splitAmong);
    }
    for (final bill in bills) {
      add(
        bill.paidBy,
        bill.amount,
        bill.splitAmong.isEmpty ? legacyBillMemberIds : bill.splitAmong,
      );
    }
    return total;
  }

  /// Simplifies debts into minimum transactions using greedy algorithm.
  List<Debt> simplifyDebts(Map<String, double> netBalances) =>
      simplifyNetBalances(netBalances);

  /// Payable pairs retain the original counterparties. Simplified net debts
  /// may route money through a third person and cannot drive pair settlements.
  List<Debt> pairDebts({
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required List<String> memberIds,
    List<SettlementModel> settlements = const [],
    List<String>? legacyBillMemberIds,
  }) {
    final ids = {
      ...memberIds,
      for (final e in expenses) ...[e.paidBy, ...e.splitAmong],
      for (final b in bills) ...[b.paidBy, ...b.splitAmong],
      for (final s in settlements) ...[s.fromUserId, s.toUserId],
    }.toList()..sort();
    final debts = <Debt>[];
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = ids[i];
        final b = ids[j];
        var net = pairBalance(
          from: a,
          to: b,
          expenses: expenses,
          bills: bills,
          legacyBillMemberIds: legacyBillMemberIds ?? memberIds,
        );
        for (final payment in settlements) {
          if (payment.status != SettlementStatus.confirmed) continue;
          if (payment.fromUserId == a && payment.toUserId == b)
            net -= payment.amount;
          if (payment.fromUserId == b && payment.toUserId == a)
            net += payment.amount;
        }
        final amount = double.parse(net.abs().toStringAsFixed(2));
        if (amount > 0)
          debts.add(
            Debt(from: net > 0 ? a : b, to: net > 0 ? b : a, amount: amount),
          );
      }
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
