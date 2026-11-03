import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/transaction_validation.dart';

PersonalTransaction _entry({
  String id = 'expense',
  double amount = 100 / 3,
  ExpenseSplit? split,
  String? source,
  double paid = 0,
}) => PersonalTransaction(
  id: id,
  title: 'Stored expense',
  amount: amount,
  type: TransactionType.expense,
  category: 'Food',
  date: DateTime(2026, 11, 2),
  userId: 'user',
  month: '2026-11',
  createdAt: DateTime(2026, 11, 2),
  split: split,
  splitSourceId: source,
  debtType: source == null ? null : DebtType.lent,
  personName: source == null ? null : 'Alex',
  settledAmount: paid,
);

void main() {
  test(
    'existing calculated amounts remain readable without entry validation',
    () {
      final entry = _entry();
      expect(entry.spendingAmount, entry.amount);
      expect(calculatePersonalMonthlySummary([entry]).expenses, entry.amount);
      expect(calculatePersonalCategorySpending([entry]), {
        'Food': entry.amount,
      });
      expect(entry.amount, 100 / 3);
    },
  );

  test(
    'stored split amounts round to paise across every display calculation',
    () {
      const split = ExpenseSplit(
        mode: ExpenseSplitMode.manual,
        shares: [
          ExpenseSplitShare(
            personName: 'Alex',
            amount: 45.123,
            debtId: 'share',
          ),
        ],
      );
      final debt = _entry(
        id: 'share',
        source: 'expense',
        amount: 45.123,
        paid: 20.123,
      );
      final parent = _entry(
        amount: 100.123,
        split: split,
      ).withSplitDebts([debt]);
      expect(split.ownShareCents(parent.amount), 5500);
      expect(parent.sharedAmount, 45.12);
      expect(parent.sharedRepaidAmount, 20.12);
      expect(parent.sharedRemainingAmount, 25);
      expect(parent.sharedStatus, 'Partially settled');
      expect(parent.spendingAmount, 80);
      expect(
        calculatePersonalMonthlySummary([parent], debts: [debt]).expenses,
        80,
      );
      expect(calculatePersonalCategorySpending([parent]), {'Food': 80});
      expect(parent.amount, 100.123);
      expect(split.shares.single.amount, 45.123);
    },
  );

  test('new entries still reject more than two decimal places', () {
    expect(() => moneyCents(100.123), throwsStateError);
    expect(
      () => validatePersonalTransactionForCreate(_entry()),
      throwsStateError,
    );
    const split = ExpenseSplit(
      mode: ExpenseSplitMode.manual,
      shares: [ExpenseSplitShare(personName: 'Alex', amount: 45.123)],
    );
    expect(() => split.validate(100), throwsStateError);
    expect(moneyCents(0.1 + 0.2), 30);
  });
}
