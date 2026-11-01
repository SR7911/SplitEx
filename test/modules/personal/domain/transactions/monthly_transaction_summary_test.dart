import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/policies/accounts/account_balance_calculator.dart';

void main() {
  PersonalTransaction entry(
    double amount,
    TransactionType type,
    String category, {
    DebtType? debtType,
    String? debtSourceId,
    String? accountId,
    String? splitSourceId,
  }) => PersonalTransaction(
    id: '$amount-$category',
    title: category,
    amount: amount,
    type: type,
    category: category,
    date: DateTime(2025, 8, 1),
    userId: 'user',
    month: '2025-08',
    createdAt: DateTime(2025, 8, 1),
    debtType: debtType,
    personName: debtType == null ? null : 'Alex',
    debtSourceId: debtSourceId,
    accountId: accountId,
    splitSourceId: splitSourceId,
  );

  test('monthly income, spending and categories match transaction values', () {
    final transactions = [
      entry(1000, TransactionType.income, 'Salary'),
      entry(125.5, TransactionType.expense, 'Food'),
      entry(24.5, TransactionType.expense, 'Food'),
      entry(50, TransactionType.expense, 'Transport'),
    ];
    final summary = calculatePersonalMonthlySummary(transactions);
    final spending = calculatePersonalCategorySpending(transactions);

    expect(summary.income, 1000);
    expect(summary.expenses, 200);
    expect(summary.remaining, 800);
    expect(summary.budgetUsage, .2);
    expect(summary.cashMovement, summary.remaining);
    expect(spending, {'Food': 150, 'Transport': 50});
  });

  test(
    'debt principal and repayments affect cash but not spending reports',
    () {
      final transactions = [
        entry(1000, TransactionType.income, 'Salary'),
        entry(200, TransactionType.expense, 'Food'),
        entry(
          500,
          TransactionType.income,
          'Other',
          debtType: DebtType.borrowed,
        ),
        entry(100, TransactionType.expense, 'Other', debtSourceId: 'borrowed'),
        entry(50, TransactionType.expense, 'Other', debtType: DebtType.lent),
        entry(30, TransactionType.income, 'Other', debtSourceId: 'lent'),
      ];
      final summary = calculatePersonalMonthlySummary(transactions);
      expect(summary.income, 1000);
      expect(summary.expenses, 200);
      expect(summary.cashMovement, 1180);
      expect(calculatePersonalCategorySpending(transactions), {'Food': 200});
    },
  );

  test('budget shortfall reconciles with linked debt payment cash flow', () {
    final transactions = [
      entry(20000, TransactionType.income, 'Salary', accountId: 'bank'),
      entry(32500, TransactionType.expense, 'Food', accountId: 'bank'),
      entry(
        2500,
        TransactionType.expense,
        'Other',
        debtSourceId: 'loan',
        accountId: 'bank',
      ),
    ];
    final summary = calculatePersonalMonthlySummary(transactions);
    expect(summary.remaining, -12500);
    expect(summary.cashMovement, -15000);
    final balances = calculateAccountBalances(
      const [
        PersonalAccount(
          id: 'bank',
          name: 'Bank',
          type: PersonalAccountType.bank,
          openingBalance: 0,
        ),
      ],
      transactions,
      const [],
    );
    expect(balances['bank'], summary.cashMovement);
  });

  test('embedded settlements affect only their payment month and account', () {
    final debt = PersonalTransaction(
      id: 'loan',
      title: 'Borrowed',
      amount: 100,
      type: TransactionType.income,
      category: 'Other',
      date: DateTime(2025, 8, 1),
      userId: 'user',
      month: '2025-08',
      createdAt: DateTime(2025, 8, 1),
      accountId: 'bank',
      debtType: DebtType.borrowed,
      personName: 'Alex',
      settlements: [
        DebtSettlement(
          amount: 40,
          date: DateTime(2025, 9, 1),
          note: 'Bank SMS',
          isWriteOff: false,
          isCashEntry: true,
          accountId: 'bank',
        ),
        DebtSettlement(
          amount: 20,
          date: DateTime(2025, 9, 2),
          note: 'Older linked payment',
          isWriteOff: false,
          repaymentId: 'legacy-payment',
        ),
      ],
    );
    final legacyPayment = entry(
      20,
      TransactionType.expense,
      'Other',
      debtSourceId: debt.id,
      accountId: 'bank',
    );
    final september = calculatePersonalMonthlySummary(
      [legacyPayment],
      debts: [debt],
      month: '2025-09',
    );
    expect(september.cashExpenses, 60);
    expect(september.expenses, 0);
    expect(
      calculatePersonalMonthlySummary(
        const [],
        debts: [debt],
        month: '2025-08',
      ).cashExpenses,
      0,
    );
    final balances = calculateAccountBalances(
      const [
        PersonalAccount(
          id: 'bank',
          name: 'Bank',
          type: PersonalAccountType.bank,
        ),
      ],
      [debt, legacyPayment],
      const [],
      debts: [debt],
    );
    expect(balances['bank'], 40);
  });
}
