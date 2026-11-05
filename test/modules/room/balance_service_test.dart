import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/policies/balance_service.dart';
import 'package:split_ex/shared/domain/policies/debt_simplifier.dart';
import 'package:split_ex/modules/room/domain/policies/split_calculator.dart';

void main() {
  final day = DateTime(2026, 10, 1);

  test(
    'removing one roommate from a dynamic split keeps the payer and remaining share',
    () {
      final selected = SplitCalculator.updateDynamicParticipants(
        selected: ['a', 'b', 'c'],
        payerId: 'a',
        memberId: 'b',
        included: false,
      );
      final balances = BalanceService().computeNetBalances(
        memberIds: ['a', 'b', 'c'],
        bills: [],
        expenses: [
          ExpenseModel(
            id: 'food',
            title: 'Food',
            amount: 90,
            category: 'Food',
            date: day,
            paidBy: 'a',
            createdBy: 'a',
            createdAt: day,
            month: '2026-10',
            splitType: SplitType.dynamic,
            splitAmong: selected,
          ),
        ],
      );
      expect(balances, {'a': 45, 'b': 0, 'c': -45});
      expect(
        SplitCalculator.updateDynamicParticipants(
          selected: selected,
          payerId: 'a',
          memberId: 'c',
          included: false,
        ),
        isEmpty,
      );
    },
  );

  test('Room expense and bill balances preserve the existing equal split', () {
    final service = BalanceService();
    final balances = service.computeNetBalances(
      memberIds: ['a', 'b', 'c'],
      expenses: [
        ExpenseModel(
          id: 'expense',
          title: 'Food',
          amount: 90,
          category: 'Food',
          date: day,
          paidBy: 'a',
          splitType: SplitType.equal,
          splitAmong: const ['a', 'b', 'c'],
          createdBy: 'a',
          createdAt: day,
          month: '2026-10',
        ),
      ],
      bills: [
        BillModel(
          id: 'bill',
          type: BillType.rent,
          amount: 60,
          splitType: 'equal',
          paidBy: 'b',
          splitAmong: const ['a', 'b', 'c'],
          month: '2026-10',
          date: day,
          createdAt: day,
        ),
      ],
    );

    expect(balances, {'a': 40, 'b': 10, 'c': -50});
    expect(
      service
          .simplifyDebts(balances)
          .map((debt) => (debt.from, debt.to, debt.amount))
          .toList(),
      [('c', 'a', 40), ('c', 'b', 10)],
    );
  });

  test('shared debt simplifier retains the existing cent threshold', () {
    final debts = simplifyNetBalances({'a': 25, 'b': -25, 'c': 0.005});
    expect(debts, hasLength(1));
    expect(
      (debts.single.from, debts.single.to, debts.single.amount),
      ('b', 'a', 25),
    );
  });
}
