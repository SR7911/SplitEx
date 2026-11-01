import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_transaction_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_account_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/policies/accounts/account_balance_calculator.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction_edit.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/debt_settlement_command.dart';
import 'package:split_ex/modules/personal/domain/use_cases/debts/settle_personal_debt.dart';
import 'package:split_ex/modules/personal/domain/use_cases/debts/tally_personal_debts.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/create_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/delete_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/edit_personal_transaction.dart';

void main() {
  late FakeFirebaseFirestore db;
  late CreatePersonalTransaction create;

  PersonalTransaction transaction({String? accountId, double amount = 50}) =>
      PersonalTransaction(
        id: '',
        title: 'Lunch',
        amount: amount,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2025, 8, 2),
        userId: 'alice',
        month: '2025-08',
        createdAt: DateTime(2025, 8, 2),
        accountId: accountId,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    create = CreatePersonalTransaction(
      FirestorePersonalTransactionRepository(firestore: db),
    );
  });

  test('writes the legacy transaction schema through the use case', () async {
    await db.doc('users/alice/personal_accounts/bank').set({'archived': false});
    await create('alice', transaction(accountId: 'bank'));
    final saved =
        (await db.collection('users/alice/personal_transactions').get())
            .docs
            .single
            .data();
    expect(saved['accountId'], 'bank');
    expect(saved['amount'], 50);
    expect(saved['date'], isA<Timestamp>());
    expect(saved['partialSettlements'], isEmpty);
    expect(saved['createdAt'], isA<Timestamp>());
  });

  test('monthly read returns pure transactions in date order', () async {
    final collection = db.collection('users/alice/personal_transactions');
    await collection.doc('old').set({
      'title': 'Old',
      'amount': 20,
      'type': 'expense',
      'category': 'Food',
      'date': Timestamp.fromDate(DateTime(2025, 8, 1)),
      'month': '2025-08',
    });
    await collection.doc('new').set({
      'title': 'New',
      'amount': 30,
      'type': 'income',
      'date': Timestamp.fromDate(DateTime(2025, 8, 3)),
      'month': '2025-08',
    });
    await collection.doc('other-month').set({
      'title': 'Other',
      'amount': 99,
      'date': Timestamp.fromDate(DateTime(2025, 9, 1)),
      'month': '2025-09',
    });
    final read = FirestorePersonalTransactionRepository(firestore: db);
    final entries = await read.transactionsForMonth('alice', '2025-08').first;

    expect(entries.map((entry) => entry.id), ['new', 'old']);
    expect(entries.first, isA<PersonalTransaction>());
    expect(entries.first.type, TransactionType.income);
    expect(entries.first.category, 'Other');
  });

  test(
    'debt read filters non-debts and keeps typed settlement history',
    () async {
      final collection = db.collection('users/alice/personal_transactions');
      await collection.doc('loan').set({
        'title': 'Loan',
        'amount': 100,
        'date': Timestamp.fromDate(DateTime(2025, 8, 2)),
        'debtType': 'lent',
        'partialSettlements': [
          {
            'amount': 25,
            'date': '2025-08-03T10:00:00.000',
            'note': 'Received',
            'type': 'payment',
          },
        ],
      });
      await collection.doc('lunch').set({
        'title': 'Lunch',
        'amount': 10,
        'date': Timestamp.fromDate(DateTime(2025, 8, 3)),
      });
      final read = FirestorePersonalTransactionRepository(firestore: db);
      final debts = await read.debts('alice').first;

      expect(debts.map((entry) => entry.id), ['loan']);
      expect(debts.single.settlements.single.amount, 25);
      expect(debts.single.settlements.single.date, DateTime(2025, 8, 3, 10));
      expect(debts.single.settlements.single.isWriteOff, isFalse);
    },
  );

  test(
    'rejects archived and missing accounts before creating a document',
    () async {
      await db.doc('users/alice/personal_accounts/archived').set({
        'archived': true,
      });
      await expectLater(
        create('alice', transaction(accountId: 'archived')),
        throwsStateError,
      );
      await expectLater(
        create('alice', transaction(accountId: 'missing')),
        throwsStateError,
      );
      await expectLater(
        create('alice', transaction(amount: 0)),
        throwsStateError,
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        isEmpty,
      );
    },
  );

  test(
    'edits and deletes through typed commands with account checks',
    () async {
      await db.doc('users/alice/personal_accounts/bank').set({
        'archived': false,
      });
      await db.doc('users/alice/personal_accounts/cash').set({
        'archived': false,
      });
      await create('alice', transaction(accountId: 'bank'));
      final doc =
          (await db.collection('users/alice/personal_transactions').get())
              .docs
              .single;
      final repository = FirestorePersonalTransactionRepository(firestore: db);
      final edit = EditPersonalTransaction(repository);
      final updated = PersonalTransactionEdit(
        title: 'Dinner',
        amount: 75,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2025, 8, 3),
        isSettled: false,
        accountId: 'cash',
      );
      await edit('alice', doc.id, updated);
      final saved = (await doc.reference.get()).data()!;
      expect(saved['title'], 'Dinner');
      expect(saved['accountId'], 'cash');
      expect(saved['month'], '2025-08');
      expect(saved['partialSettlements'], isEmpty);

      await expectLater(
        edit(
          'alice',
          doc.id,
          PersonalTransactionEdit(
            title: 'Dinner',
            amount: 75,
            type: TransactionType.expense,
            category: 'Food',
            date: DateTime(2025, 8, 3),
            isSettled: false,
            accountId: 'missing',
          ),
        ),
        throwsStateError,
      );
      await DeletePersonalTransaction(repository)('alice', doc.id);
      expect((await doc.reference.get()).exists, isFalse);
    },
  );

  test('partial and full settlements update only the original debt', () async {
    final debt = db.doc('users/alice/personal_transactions/loan');
    await debt.set({
      'title': 'Loan',
      'amount': 100,
      'date': Timestamp.fromDate(DateTime(2025, 8, 1)),
      'debtType': 'lent',
      'personName': 'Alex',
      'category': 'Loan',
      'isSettled': false,
    });
    final settle = SettlePersonalDebt(
      FirestorePersonalTransactionRepository(firestore: db),
    );
    await settle(
      'alice',
      'loan',
      DebtSettlementCommand(
        action: DebtSettlementAction.partial,
        amount: 25,
        note: 'Received cash',
        date: DateTime(2025, 8, 3),
      ),
    );

    final saved = (await debt.get()).data()!;
    expect(saved['settledAmount'], 25);
    expect(saved['isSettled'], isFalse);
    expect(saved['partialSettlements'], hasLength(1));
    expect((saved['partialSettlements'] as List).single['cashEntry'], isTrue);
    expect(
      (await db.collection('users/alice/personal_transactions').get()).docs,
      hasLength(1),
    );

    await settle(
      'alice',
      'loan',
      DebtSettlementCommand(
        action: DebtSettlementAction.full,
        date: DateTime(2025, 8, 4),
      ),
    );
    final completed = (await debt.get()).data()!;
    expect(completed['settledAmount'], 100);
    expect(completed['isSettled'], isTrue);
    expect(completed['partialSettlements'], hasLength(2));
    expect(
      (await db.collection('users/alice/personal_transactions').get()).docs,
      hasLength(1),
    );
  });

  test('write-off closes debt without creating a repayment', () async {
    final debt = db.doc('users/alice/personal_transactions/loan');
    await debt.set({
      'title': 'Loan',
      'amount': 100,
      'date': Timestamp.fromDate(DateTime(2025, 8, 1)),
      'debtType': 'lent',
      'personName': 'Alex',
      'isSettled': false,
    });
    final settle = SettlePersonalDebt(
      FirestorePersonalTransactionRepository(firestore: db),
    );
    await settle(
      'alice',
      'loan',
      const DebtSettlementCommand(action: DebtSettlementAction.writeOff),
    );

    final saved = (await debt.get()).data()!;
    expect(saved['writtenOffAmount'], 100);
    expect(saved['isSettled'], isTrue);
    expect(
      (await db.collection('users/alice/personal_transactions').get()).docs,
      hasLength(1),
    );
  });

  test(
    'borrowed repayment stays on its debt and adjusts its chosen account',
    () async {
      await db.doc('users/alice/personal_accounts/bank').set({
        'archived': false,
      });
      final repository = FirestorePersonalTransactionRepository(firestore: db);
      await CreatePersonalTransaction(repository)(
        'alice',
        PersonalTransaction(
          id: '',
          title: 'Borrowed from Alex',
          amount: 200,
          type: TransactionType.income,
          category: 'Other',
          date: DateTime(2025, 8, 1),
          userId: 'alice',
          month: '2025-08',
          createdAt: DateTime(2025, 8, 1),
          accountId: 'bank',
          debtType: DebtType.borrowed,
          personName: 'Alex',
        ),
      );
      final debt = (await repository.debts('alice').first).single;
      await expectLater(
        SettlePersonalDebt(repository)(
          'alice',
          debt.id,
          DebtSettlementCommand(
            action: DebtSettlementAction.partial,
            amount: 100,
            date: DateTime(2025, 8, 2),
            accountId: 'missing',
          ),
        ),
        throwsStateError,
      );
      expect(
        (await repository.debts('alice').first).single.remainingAmount,
        200,
      );
      await SettlePersonalDebt(repository)(
        'alice',
        debt.id,
        DebtSettlementCommand(
          action: DebtSettlementAction.partial,
          amount: 100,
          date: DateTime(2025, 8, 2),
          accountId: 'bank',
        ),
      );
      final updated = (await repository.debts('alice').first).single;
      expect(updated.remainingAmount, 100);
      expect(updated.settlements.single.accountId, 'bank');
      expect(updated.settlements.single.isCashEntry, isTrue);
      final month = await repository
          .transactionsForMonth('alice', '2025-08')
          .first;
      expect(month, hasLength(1));
      final assigned = await FirestorePersonalAccountRepository(
        firestore: db,
      ).assignedTransactions('alice').first;
      final balances = calculateAccountBalances(
        const [
          PersonalAccount(
            id: 'bank',
            name: 'Bank',
            type: PersonalAccountType.bank,
            openingBalance: 0,
          ),
        ],
        assigned,
        const [],
        debts: [updated],
      );
      expect(balances['bank'], 100);
      await expectLater(repository.delete('alice', debt.id), throwsStateError);
    },
  );

  test('borrowed partial settlement creates no separate transaction', () async {
    final debt = db.doc('users/alice/personal_transactions/loan');
    await debt.set({
      'title': 'Loan',
      'amount': 100,
      'date': Timestamp.fromDate(DateTime(2025, 8, 1)),
      'debtType': 'borrowed',
      'personName': 'Alex',
      'isSettled': false,
    });
    await SettlePersonalDebt(
      FirestorePersonalTransactionRepository(firestore: db),
    )(
      'alice',
      'loan',
      DebtSettlementCommand(
        action: DebtSettlementAction.partial,
        amount: 40,
        note: 'Repaid',
        date: DateTime(2025, 8, 3),
      ),
    );

    expect((await debt.get()).data()!['settledAmount'], 40);
    final docs =
        (await db.collection('users/alice/personal_transactions').get()).docs;
    expect(docs, hasLength(1));
    expect(
      (docs.single.data()['partialSettlements'] as List).single['cashEntry'],
      isTrue,
    );
  });

  test(
    'split expense creates debts without duplicating monthly spending',
    () async {
      final repository = FirestorePersonalTransactionRepository(firestore: db);
      await CreatePersonalTransaction(repository)(
        'alice',
        PersonalTransaction(
          id: '',
          title: 'Dinner',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2025, 8, 2),
          userId: 'alice',
          month: '2025-08',
          createdAt: DateTime(2025, 8, 2),
          split: equalExpenseSplit(100, ['Alex', 'Sam']),
        ),
      );
      final monthly = await repository
          .transactionsForMonth('alice', '2025-08')
          .first;
      final debts = await repository.debts('alice').first;
      expect(monthly, hasLength(1));
      expect(monthly.single.amount, 100);
      expect(monthly.single.split!.ownShareCents(100), 3334);
      expect(debts, hasLength(2));
      expect(
        debts.every((debt) => debt.splitSourceId == monthly.single.id),
        isTrue,
      );
      expect(debts.map((debt) => debt.amount), [33.33, 33.33]);
    },
  );

  test(
    'manual shares cannot exceed the total and edit preserves linked debts',
    () async {
      final repository = FirestorePersonalTransactionRepository(firestore: db);
      final invalid = ExpenseSplit(
        mode: ExpenseSplitMode.manual,
        shares: const [
          ExpenseSplitShare(personName: 'Alex', amount: 60),
          ExpenseSplitShare(personName: 'Sam', amount: 50),
        ],
      );
      expect(() => invalid.validate(100), throwsStateError);
      await CreatePersonalTransaction(repository)(
        'alice',
        PersonalTransaction(
          id: '',
          title: 'Dinner',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2025, 8, 2),
          userId: 'alice',
          month: '2025-08',
          createdAt: DateTime(2025, 8, 2),
          split: const ExpenseSplit(
            mode: ExpenseSplitMode.manual,
            shares: [
              ExpenseSplitShare(personName: 'Alex', amount: 60),
              ExpenseSplitShare(personName: 'Sam', amount: 30),
            ],
          ),
        ),
      );
      final parent =
          (await repository.transactionsForMonth('alice', '2025-08').first)
              .single;
      final alexId = parent.split!.shares
          .singleWhere((s) => s.personName == 'Alex')
          .debtId!;
      await EditPersonalTransaction(repository)(
        'alice',
        parent.id,
        PersonalTransactionEdit(
          title: 'Dinner updated',
          amount: 120,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2025, 8, 2),
          isSettled: false,
          split: const ExpenseSplit(
            mode: ExpenseSplitMode.manual,
            shares: [
              ExpenseSplitShare(personName: 'Alex', amount: 70),
              ExpenseSplitShare(personName: 'Sam', amount: 40),
            ],
          ),
        ),
      );
      final updated =
          (await db.doc('users/alice/personal_transactions/$alexId').get())
              .data()!;
      expect(updated['amount'], 70);
      expect(updated['title'], 'Share of Dinner updated');
      expect(
        (await repository.transactionsForMonth('alice', '2025-08').first)
            .single
            .amount,
        120,
      );
      await EditPersonalTransaction(repository)(
        'alice',
        parent.id,
        PersonalTransactionEdit(
          title: 'Dinner updated',
          amount: 120,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime(2025, 8, 2),
          isSettled: false,
        ),
      );
      expect(
        (await repository.transactionsForMonth('alice', '2025-08').first)
            .single
            .split,
        isNull,
      );
      expect(await repository.debts('alice').first, isEmpty);
    },
  );

  test('settled split share cannot be reduced or removed', () async {
    final repository = FirestorePersonalTransactionRepository(firestore: db);
    await CreatePersonalTransaction(repository)(
      'alice',
      PersonalTransaction(
        id: '',
        title: 'Dinner',
        amount: 100,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2025, 8, 2),
        userId: 'alice',
        month: '2025-08',
        createdAt: DateTime(2025, 8, 2),
        split: const ExpenseSplit(
          mode: ExpenseSplitMode.manual,
          shares: [ExpenseSplitShare(personName: 'Alex', amount: 60)],
        ),
      ),
    );
    final parent =
        (await repository.transactionsForMonth('alice', '2025-08').first)
            .single;
    final childId = parent.split!.shares.single.debtId!;
    await SettlePersonalDebt(repository)(
      'alice',
      childId,
      DebtSettlementCommand(
        action: DebtSettlementAction.partial,
        amount: 20,
        date: DateTime(2025, 8, 3),
      ),
    );
    Future<void> editWith(ExpenseSplit? split) =>
        EditPersonalTransaction(repository)(
          'alice',
          parent.id,
          PersonalTransactionEdit(
            title: 'Dinner',
            amount: 100,
            type: TransactionType.expense,
            category: 'Food',
            date: DateTime(2025, 8, 2),
            isSettled: false,
            split: split,
          ),
        );
    await expectLater(
      editWith(
        const ExpenseSplit(
          mode: ExpenseSplitMode.manual,
          shares: [ExpenseSplitShare(personName: 'Alex', amount: 10)],
        ),
      ),
      throwsStateError,
    );
    await expectLater(editWith(null), throwsStateError);
    await expectLater(
      DeletePersonalTransaction(repository)('alice', parent.id),
      throwsStateError,
    );
    expect(
      (await db.doc('users/alice/personal_transactions/$childId').get())
          .data()!['amount'],
      60,
    );
  });

  test(
    'tally offsets opposing debts without creating a cash transaction',
    () async {
      final collection = db.collection('users/alice/personal_transactions');
      for (final entry in [
        ('borrowed', 200, 'older'),
        ('lent', 100, 'newer'),
      ]) {
        await collection.doc(entry.$3).set({
          'title': entry.$3,
          'amount': entry.$2,
          'type': 'expense',
          'category': 'Other',
          'date': Timestamp.fromDate(
            DateTime(2025, 8, entry.$3 == 'older' ? 1 : 2),
          ),
          'month': '2025-08',
          'debtType': entry.$1,
          'personName': 'Alex',
          'isSettled': false,
        });
      }
      final repository = FirestorePersonalTransactionRepository(firestore: db);
      await expectLater(
        TallyPersonalDebts(repository)(
          'alice',
          'Alex',
          expectedOffsetCents: 5000,
          expectedNetCents: -10000,
        ),
        throwsStateError,
      );
      expect(
        (await collection.doc('older').get()).data()!['settledAmount'],
        isNull,
      );
      await TallyPersonalDebts(repository)(
        'alice',
        ' alex ',
        expectedOffsetCents: 10000,
        expectedNetCents: -10000,
      );
      final borrowed = (await collection.doc('older').get()).data()!;
      final lent = (await collection.doc('newer').get()).data()!;
      expect(borrowed['settledAmount'], 100);
      expect(borrowed['isSettled'], false);
      expect(lent['settledAmount'], 100);
      expect(lent['isSettled'], true);
      expect((borrowed['partialSettlements'] as List).single['type'], 'tally');
      expect((await collection.get()).docs, hasLength(2));
      await expectLater(
        TallyPersonalDebts(repository)('alice', 'Alex'),
        throwsStateError,
      );
    },
  );
}
