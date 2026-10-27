import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_transfer.dart';
import 'package:split_ex/modules/personal/domain/policies/accounts/account_balance_calculator.dart';
import 'package:split_ex/modules/personal/data/mappers/accounts/account_firestore_mapper.dart'
    show LegacyAccountSerialization;
import 'support/personal_transaction_fixture.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_account_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_transaction_repository.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/create_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/data/repositories/bank_sms_repository.dart';

void main() {
  final date = DateTime(2026, 10, 20);
  const accounts = [
    PersonalAccount(
      id: 'bank',
      name: 'Bank',
      type: PersonalAccountType.bank,
      openingBalance: 10000,
      last4: '1234',
    ),
    PersonalAccount(
      id: 'cash',
      name: 'Cash',
      type: PersonalAccountType.cash,
      openingBalance: 1000,
    ),
    PersonalAccount(
      id: 'card',
      name: 'Card',
      type: PersonalAccountType.creditCard,
      openingBalance: -2000,
    ),
  ];
  PersonalTransactionModel entry(
    String id,
    double amount,
    TransactionType type,
    String? accountId,
  ) => PersonalTransactionModel(
    id: id,
    title: id,
    amount: amount,
    type: type,
    category: 'Other',
    date: date,
    userId: 'alice',
    month: '2026-10',
    createdAt: date,
    accountId: accountId,
  );
  late FakeFirebaseFirestore db;
  late FirestorePersonalAccountRepository service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    service = FirestorePersonalAccountRepository(firestore: db);
    for (final a in accounts) {
      await db.doc('users/alice/personal_accounts/${a.id}').set(a.toMap());
    }
  });
  final sms = BankSmsParser().parse(
    id: 'alert',
    sender: 'VM-TESTBK',
    body:
        'INR 500 debited from A/c XX1234 to SHOP on 20/10/2026 UPI Ref 629300123456.',
    receivedAt: date,
  )!;

  test(
    'cash withdrawal and credit-card repayment change accounts without changing net money',
    () {
      final transfers = [
        PersonalTransfer(
          id: 'withdraw',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: 500,
          date: date,
        ),
        PersonalTransfer(
          id: 'repay',
          fromAccountId: 'bank',
          toAccountId: 'card',
          amount: 1000,
          date: date,
        ),
      ];
      final balances = calculateAccountBalances(accounts, [
        entry('food', 200, TransactionType.expense, 'card'),
        entry('salary', 2000, TransactionType.income, 'bank'),
        entry('old', 9999, TransactionType.expense, null),
      ], transfers);
      expect(balances, {'bank': 10500, 'cash': 1500, 'card': -1200});
      expect(balances.values.fold(0.0, (a, b) => a + b), 10800);
    },
  );
  test(
    'personal entries persist assignments and reject missing or archived accounts',
    () async {
      final expenses = FirestorePersonalTransactionRepository(firestore: db);
      await CreatePersonalTransaction(expenses)(
        'alice',
        entry('food', 100, TransactionType.expense, 'bank'),
      );
      final saved =
          (await db.collection('users/alice/personal_transactions').get())
              .docs
              .single;
      expect(saved.data()['accountId'], 'bank');
      await expenses.updateRaw('alice', saved.id, {
        'accountId': 'cash',
      });
      expect((await saved.reference.get()).get('accountId'), 'cash');
      await service.archive('alice', 'cash', true);
      await expenses.updateRaw('alice', saved.id, {
        'accountId': 'cash',
        'title': 'Updated',
      });
      await expectLater(
        CreatePersonalTransaction(expenses)(
          'alice',
          entry('bad', 1, TransactionType.expense, 'cash'),
        ),
        throwsStateError,
      );
      await expectLater(
        expenses.updateRaw('alice', saved.id, {'accountId': 'missing'}),
        throwsStateError,
      );
    },
  );
  test('repayment dates cannot precede a debt transaction date', () async {
    final expenses = FirestorePersonalTransactionRepository(firestore: db);
    final debt = PersonalTransactionModel(
      id: '',
      title: 'Debt',
      amount: 100,
      type: TransactionType.expense,
      category: 'Other',
      date: date,
      userId: 'alice',
      month: '2026-10',
      createdAt: date,
      debtType: DebtType.lent,
      personName: 'Alex',
      dueDate: date.subtract(const Duration(days: 1)),
    );
    await expectLater(
      CreatePersonalTransaction(expenses)('alice', debt),
      throwsStateError,
    );
    await db.doc('users/alice/personal_transactions/debt').set({
      ...debt.toMap(),
      'dueDate': Timestamp.fromDate(date.add(const Duration(days: 1))),
    });
    await expectLater(
      expenses.updateRaw('alice', 'debt', {
        'dueDate': Timestamp.fromDate(date.subtract(const Duration(days: 1))),
      }),
      throwsStateError,
    );
  });
  test(
    'derived balances reflect edits, deletions and account reassignment',
    () {
      expect(
        calculateAccountBalances(accounts, [
          entry('food', 500, TransactionType.expense, 'bank'),
        ], [])['bank'],
        9500,
      );
      expect(
        calculateAccountBalances(accounts, [
          entry('food', 300, TransactionType.expense, 'cash'),
        ], []),
        {'bank': 10000, 'cash': 700, 'card': -2000},
      );
      expect(calculateAccountBalances(accounts, [], [])['bank'], 10000);
    },
  );
  test('paise arithmetic avoids cumulative floating point balance drift', () {
    expect(
      calculateAccountBalances(accounts, [
        entry('one', .1, TransactionType.expense, 'cash'),
        entry('two', .2, TransactionType.expense, 'cash'),
      ], [])['cash'],
      999.7,
    );
  });
  test(
    'transfers are stored independently of expense and income records',
    () async {
      await service.saveTransfer(
        'alice',
        PersonalTransfer(
          id: 'one',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: 500,
          date: date,
        ),
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        isEmpty,
      );
      expect(
        (await db.doc('users/alice/personal_transfers/one').get()).get(
          'amount',
        ),
        500,
      );
      await service.saveTransfer(
        'alice',
        PersonalTransfer(
          id: 'one',
          fromAccountId: 'bank',
          toAccountId: 'card',
          amount: 700,
          date: date,
        ),
      );
      expect(
        (await db.collection('users/alice/personal_transfers').get())
            .docs
            .length,
        1,
      );
      await service.deleteTransfer('alice', 'one');
      expect(
        (await db.collection('users/alice/personal_transfers').get()).docs,
        isEmpty,
      );
    },
  );
  test(
    'transfer rejects same account, invalid amounts, unknown or another user account',
    () async {
      for (final t in [
        PersonalTransfer(
          id: '',
          fromAccountId: 'bank',
          toAccountId: 'bank',
          amount: 1,
          date: date,
        ),
        PersonalTransfer(
          id: '',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: double.nan,
          date: date,
        ),
        PersonalTransfer(
          id: '',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: .001,
          date: date,
        ),
        PersonalTransfer(
          id: '',
          fromAccountId: 'bank',
          toAccountId: 'missing',
          amount: 1,
          date: date,
        ),
      ]) {
        await expectLater(service.saveTransfer('alice', t), throwsStateError);
      }
      await expectLater(
        service.saveTransfer(
          'bob',
          PersonalTransfer(
            id: '',
            fromAccountId: 'bank',
            toAccountId: 'cash',
            amount: 1,
            date: date,
          ),
        ),
        throwsStateError,
      );
      expect(
        (await db.collection('users/alice/personal_transfers').get()).docs,
        isEmpty,
      );
    },
  );
  test('archiving preserves history and disallows new transfers', () async {
    await service.archive('alice', 'cash', true);
    expect(
      (await service.accounts('alice').first)
          .firstWhere((a) => a.id == 'cash')
          .archived,
      true,
    );
    await expectLater(
      service.saveTransfer(
        'alice',
        PersonalTransfer(
          id: '',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: 1,
          date: date,
        ),
      ),
      throwsStateError,
    );
    expect(
      (await db.doc('users/alice/personal_accounts/cash').get()).exists,
      true,
    );
  });
  test(
    'assigned-entry query includes account entries but excludes null and legacy entries',
    () async {
      await db
          .doc('users/alice/personal_transactions/assigned')
          .set(entry('assigned', 1, TransactionType.expense, 'bank').toMap());
      await db
          .doc('users/alice/personal_transactions/legacy')
          .set(entry('legacy', 1, TransactionType.expense, null).toMap());
      await db.doc('users/alice/personal_transactions/null').set({
        ...entry('null', 1, TransactionType.expense, null).toMap(),
        'accountId': null,
      });
      expect(
        (await service.assignedTransactions('alice').first).map((e) => e.id),
        ['assigned'],
      );
    },
  );
  test('automatic SMS assigns a unique active account ending', () async {
    final repo = BankSmsRepository(firestore: db);
    await repo.save('alice', sms, matchAccount: true);
    expect(
      (await db
              .doc('users/alice/personal_transactions/${sms.transactionId}')
              .get())
          .get('accountId'),
      'bank',
    );
  });
  test('ambiguous account endings remain unassigned', () async {
    await db.doc('users/alice/personal_accounts/other-bank').set({
      ...accounts.first.toMap(),
      'name': 'Other bank',
    });
    await BankSmsRepository(
      firestore: db,
    ).save('alice', sms, matchAccount: true);
    expect(
      (await db
              .doc('users/alice/personal_transactions/${sms.transactionId}')
              .get())
          .data()!
          .containsKey('accountId'),
      false,
    );
  });
  test(
    'reviewed SMS transfers create no expense and retain duplicate protection',
    () async {
      final repo = BankSmsRepository(firestore: db);
      await repo.saveTransfer(
        'alice',
        sms,
        fromAccountId: 'bank',
        toAccountId: 'cash',
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        isEmpty,
      );
      expect(
        (await db.collection('users/alice/personal_transfers').get())
            .docs
            .length,
        1,
      );
      expect(await repo.wasRecorded('alice', sms), true);
      expect(
        await repo.saveTransfer(
          'alice',
          sms,
          fromAccountId: 'bank',
          toAccountId: 'cash',
        ),
        BankSmsSaveResult.duplicate,
      );
      await db
          .doc('users/alice/personal_transfers/${sms.transactionId}')
          .delete();
      await repo.saveTransfer(
        'alice',
        sms,
        fromAccountId: 'bank',
        toAccountId: 'cash',
      );
      expect(
        (await db.collection('users/alice/personal_transfers').get()).docs,
        isEmpty,
      );
    },
  );
  test(
    'opposite SMS alerts can link the same transfer without double-counting',
    () async {
      final repo = BankSmsRepository(firestore: db);
      await service.saveTransfer(
        'alice',
        PersonalTransfer(
          id: 'withdrawal',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: 500,
          date: date,
        ),
      );
      final match = (await repo.possibleMatches('alice', sms)).single;
      expect(match.isTransfer, true);
      await repo.saveTransfer('alice', sms, existingId: match.id);
      final credit = BankSmsParser().parse(
        id: 'credit',
        sender: 'VM-TESTBK',
        body:
            'INR 500 credited to A/c XX9876 from BANK on 20/10/2026 UPI Ref 629300123456.',
        receivedAt: date,
      )!;
      await repo.saveTransfer('alice', credit, existingId: match.id);
      expect(
        (await db.collection('users/alice/personal_transfers').get())
            .docs
            .length,
        1,
      );
      expect(await repo.wasRecorded('alice', credit), true);
    },
  );
  test(
    'a transfer changed after review cannot be linked to the wrong amount',
    () async {
      await service.saveTransfer(
        'alice',
        PersonalTransfer(
          id: 'changed',
          fromAccountId: 'bank',
          toAccountId: 'cash',
          amount: 600,
          date: date,
        ),
      );
      final repo = BankSmsRepository(firestore: db);
      await expectLater(
        repo.saveTransfer('alice', sms, existingId: 'changed'),
        throwsStateError,
      );
      expect(await repo.wasRecorded('alice', sms), false);
    },
  );
  test(
    'new account collection rules restrict both collections to their owner',
    () async {
      final rules = File('firestore.rules').readAsStringSync();
      for (final name in ['personal_accounts', 'personal_transfers']) {
        final block = RegExp(
          'match /$name/\\{[^}]+\\} \\{[\\s\\S]*?\\n      \\}',
        ).firstMatch(rules)!.group(0)!;
        final secured = FakeFirebaseFirestore(
          securityRules:
              'service cloud.firestore { match /databases/{database}/documents { match /users/{userId} { $block } } }',
        );
        secured.authObject.add({
          'uid': 'alice',
          'token': {'email': 'alice@example.com'},
        });
        await secured.doc('users/alice/$name/one').set({'name': 'Private'});
        secured.authObject.add({
          'uid': 'bob',
          'token': {'email': 'bob@example.com'},
        });
        await expectLater(
          secured.doc('users/alice/$name/one').get(),
          throwsException,
        );
        await expectLater(
          secured.doc('users/alice/$name/two').set({'name': 'Invalid'}),
          throwsException,
        );
      }
    },
  );
}
