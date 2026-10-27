import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_transfer.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/accounts/account_balance_calculator.dart';
import 'package:split_ex/modules/personal/domain/policies/accounts/account_validation.dart';

void main() {
  const accounts = [
    PersonalAccount(
      id: 'bank',
      name: 'Bank',
      type: PersonalAccountType.bank,
      openingBalance: 100,
    ),
    PersonalAccount(
      id: 'cash',
      name: 'Cash',
      type: PersonalAccountType.cash,
    ),
  ];
  final date = DateTime(2026, 10, 26);

  test('balance policy is pure and preserves money during transfers', () {
    final balances = calculateAccountBalances(
      accounts,
      [
        PersonalTransaction(
          id: 'salary',
          title: 'Salary',
          amount: 20.01,
          type: TransactionType.income,
          category: 'Income',
          date: date,
          userId: 'alice',
          month: '2026-10',
          createdAt: date,
          accountId: 'bank',
        ),
      ],
      [
        PersonalTransfer(
          id: 'withdrawal',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: 10.01,
          date: date,
        ),
      ],
    );

    expect(balances, {'bank': 110, 'cash': 10.01});
    expect(balances.values.reduce((a, b) => a + b), 120.01);
  });

  test('validation rejects malformed account and sub-paise transfer', () {
    expect(
      () => validatePersonalAccount(
        const PersonalAccount(
          id: '',
          name: '',
          type: PersonalAccountType.bank,
        ),
      ),
      throwsStateError,
    );
    expect(
      () => validatePersonalTransfer(
        PersonalTransfer(
          id: '',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: .001,
          date: date,
        ),
      ),
      throwsStateError,
    );
  });
}
