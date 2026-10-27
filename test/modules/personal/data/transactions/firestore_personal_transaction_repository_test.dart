import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_transaction_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction_edit.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/debt_settlement_command.dart';
import 'package:split_ex/modules/personal/domain/use_cases/debts/settle_personal_debt.dart';
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

  test('partial and full settlements record history and repayments', () async {
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
    final repayments =
        (await db.collection('users/alice/personal_transactions').get()).docs
            .where((doc) => doc.id != 'loan')
            .toList();
    expect(repayments, hasLength(1));
    expect(repayments.single.data()['amount'], 25);
    expect(repayments.single.data()['type'], 'income');

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
      hasLength(3),
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
    'borrowed partial settlement creates a linked repayment expense',
    () async {
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
      final repayment =
          (await db.collection('users/alice/personal_transactions').get()).docs
              .singleWhere((doc) => doc.id != 'loan');
      expect(repayment.data()['type'], 'expense');
      expect(repayment.data()['debtSourceId'], 'loan');
    },
  );
}
