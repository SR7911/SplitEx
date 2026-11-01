import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_bank_sms_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreBankSmsRepository repo;
  final sms = BankSmsParser().parse(
    id: 'sms-one',
    sender: 'VM-TESTBK',
    body:
        'INR 500 debited from A/c XX1234 to SHOP on 20/10/2026 UPI Ref 629300123456.',
    receivedAt: DateTime(2026, 10, 20, 12),
  )!;
  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreBankSmsRepository(firestore: db);
  });

  test(
    'atomic import produces an expense and a durable receipt without uploading raw SMS',
    () async {
      expect(await repo.save('alice', sms), BankSmsSaveResult.recorded);
      final docs = await db
          .collection('users/alice/personal_transactions')
          .get();
      expect(docs.docs.length, 1);
      final data = docs.docs.single.data();
      expect(data['amount'], 500);
      expect(data['type'], 'expense');
      expect(data['month'], '2026-10');
      expect(data['bankAccountLast4'], '1234');
      expect(data['bankReference'], '629300123456');
      expect(data.containsKey('body'), isFalse);
      expect(data.values.contains(sms.body), isFalse);
      expect(await repo.wasRecorded('alice', sms), isTrue);
    },
  );
  test('repeated deliveries do not create a second transaction', () async {
    await repo.save('alice', sms);
    expect(await repo.save('alice', sms), BankSmsSaveResult.duplicate);
    expect(
      (await db.collection('users/alice/personal_transactions').get())
          .docs
          .length,
      1,
    );
  });
  test(
    'debit SMS partially settles a borrowed debt without another transaction',
    () async {
      final debt = db.doc('users/alice/personal_transactions/borrowed');
      await debt.set({
        'title': 'Borrowed from Alex',
        'amount': 700,
        'type': 'income',
        'debtType': 'borrowed',
        'personName': 'Alex',
        'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'settledAmount': 0,
        'isSettled': false,
        'partialSettlements': [],
      });
      await db.doc('users/alice/personal_accounts/bank').set({
        'archived': false,
      });

      final candidates = await repo.openDebtsForSms('alice', sms);
      expect(candidates.map((item) => item.id), ['borrowed']);
      expect(
        await repo.saveDebtSettlement(
          'alice',
          sms,
          allocations: [
            BankSmsDebtAllocation(
              debtId: 'borrowed',
              amountMinor: sms.amountMinor,
            ),
          ],
          accountId: 'bank',
        ),
        BankSmsSaveResult.recorded,
      );
      final saved = (await debt.get()).data()!;
      expect(saved['settledAmount'], 500);
      expect(saved['isSettled'], isFalse);
      expect((saved['partialSettlements'] as List).single['cashEntry'], isTrue);
      expect((saved['partialSettlements'] as List).single['accountId'], 'bank');
      expect(await repo.wasRecorded('alice', sms), isTrue);
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        hasLength(1),
      );
      expect(
        await repo.saveDebtSettlement(
          'alice',
          sms,
          allocations: [
            BankSmsDebtAllocation(
              debtId: 'borrowed',
              amountMinor: sms.amountMinor,
            ),
          ],
        ),
        BankSmsSaveResult.duplicate,
      );
      expect(
        ((await debt.get()).data()!['partialSettlements'] as List),
        hasLength(1),
      );
    },
  );

  test(
    'credit SMS fully settles a lent debt without another transaction',
    () async {
      final credit = BankSmsParser().parse(
        id: 'lent-repayment',
        sender: 'VM-TESTBK',
        body:
            'INR 300 credited to A/c XX1234 from ALEX on 20/10/2026 UPI Ref 629300123457.',
        receivedAt: DateTime(2026, 10, 20, 12),
      )!;
      expect(credit.direction, BankSmsDirection.credit);
      final debt = db.doc('users/alice/personal_transactions/lent');
      await debt.set({
        'title': 'Lent to Alex',
        'amount': 300,
        'type': 'expense',
        'debtType': 'lent',
        'personName': 'Alex',
        'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'settledAmount': 0,
        'isSettled': false,
        'partialSettlements': [],
      });
      expect((await repo.openDebtsForSms('alice', credit)).single.id, 'lent');
      expect(
        await repo.saveDebtSettlement(
          'alice',
          credit,
          allocations: [
            BankSmsDebtAllocation(
              debtId: 'lent',
              amountMinor: credit.amountMinor,
            ),
          ],
        ),
        BankSmsSaveResult.recorded,
      );
      final saved = (await debt.get()).data()!;
      expect(saved['settledAmount'], 300);
      expect(saved['isSettled'], isTrue);
      expect(
        (saved['partialSettlements'] as List).single['bankSmsReceiptId'],
        credit.transactionId,
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        hasLength(1),
      );
      expect(await repo.wasRecorded('alice', credit), isTrue);
    },
  );
  test('invalid debt link leaves the debt and SMS review untouched', () async {
    final debt = db.doc('users/alice/personal_transactions/lent');
    await debt.set({
      'title': 'Lent to Alex',
      'amount': 300,
      'type': 'expense',
      'debtType': 'lent',
      'personName': 'Alex',
      'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
      'settledAmount': 0,
      'isSettled': false,
      'partialSettlements': [],
    });
    await expectLater(
      repo.saveDebtSettlement(
        'alice',
        sms,
        allocations: [
          BankSmsDebtAllocation(debtId: 'lent', amountMinor: sms.amountMinor),
        ],
      ),
      throwsStateError,
    );
    expect((await debt.get()).data()!['settledAmount'], 0);
    expect(await repo.wasRecorded('alice', sms), isFalse);

    await debt.update({'debtType': 'borrowed'});
    await expectLater(
      repo.saveDebtSettlement(
        'alice',
        sms,
        allocations: [
          BankSmsDebtAllocation(debtId: 'lent', amountMinor: sms.amountMinor),
        ],
      ),
      throwsStateError,
    );
    expect((await debt.get()).data()!['settledAmount'], 0);
    expect(await repo.wasRecorded('alice', sms), isFalse);
  });
  test(
    'one credit SMS closes a preferred debt and partially pays the next',
    () async {
      final credit = BankSmsParser().parse(
        id: 'combined-repayment',
        sender: 'VM-TESTBK',
        body: 'INR 500 credited to A/c XX1234 from ALEX UPI Ref 629300123458.',
        receivedAt: DateTime(2026, 10, 20),
      )!;
      final preferred = db.doc('users/alice/personal_transactions/preferred');
      final other = db.doc('users/alice/personal_transactions/other');
      for (final item in [(preferred, 200, 'Alex'), (other, 400, ' alex ')]) {
        await item.$1.set({
          'title': 'Lent',
          'amount': item.$2,
          'type': 'expense',
          'debtType': 'lent',
          'personName': item.$3,
          'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
          'settledAmount': 0,
          'isSettled': false,
          'partialSettlements': [],
        });
      }
      final allocations = [
        const BankSmsDebtAllocation(debtId: 'preferred', amountMinor: 20000),
        const BankSmsDebtAllocation(debtId: 'other', amountMinor: 30000),
      ];
      await expectLater(
        repo.saveDebtSettlement(
          'alice',
          credit,
          allocations: const [
            BankSmsDebtAllocation(debtId: 'preferred', amountMinor: 20000),
          ],
        ),
        throwsStateError,
      );
      expect((await preferred.get()).data()!['settledAmount'], 0);
      expect(await repo.wasRecorded('alice', credit), isFalse);
      expect(
        await repo.saveDebtSettlement(
          'alice',
          credit,
          allocations: allocations,
        ),
        BankSmsSaveResult.recorded,
      );
      expect((await preferred.get()).data()!['isSettled'], isTrue);
      expect((await other.get()).data()!['isSettled'], isFalse);
      expect((await other.get()).data()!['settledAmount'], 300);
      expect(
        ((await preferred.get()).data()!['partialSettlements'] as List)
            .single['bankSmsReceiptId'],
        credit.transactionId,
      );
      final receipt = await db
          .doc('users/alice/bank_sms_receipts/${credit.transactionId}')
          .get();
      expect((receipt.data()!['allocations'] as List), hasLength(2));
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        hasLength(2),
      );
      expect(
        await repo.saveDebtSettlement(
          'alice',
          credit,
          allocations: allocations,
        ),
        BankSmsSaveResult.duplicate,
      );
      expect((await other.get()).data()!['settledAmount'], 300);
    },
  );
  test(
    'user edits and deletes are respected when the same SMS is redelivered',
    () async {
      await repo.save('alice', sms);
      final target = db.doc(
        'users/alice/personal_transactions/${sms.transactionId}',
      );
      await target.update({'amount': 450, 'title': 'Corrected amount'});
      await repo.save('alice', sms);
      expect((await target.get()).get('amount'), 450);
      await target.delete();
      await repo.save('alice', sms);
      expect((await target.get()).exists, isFalse);
    },
  );
  test('possible EMI or manual duplicates are returned for review', () async {
    await db.doc('users/alice/personal_transactions/emi').set({
      'amount': 500,
      'type': 'expense',
      'title': 'Loan EMI',
      'date': Timestamp.fromDate(DateTime(2026, 10, 20)),
      'loanSourceId': 'loan-one',
    });
    await db.doc('users/alice/personal_transactions/income').set({
      'amount': 500,
      'type': 'income',
      'title': 'Other receipt',
      'date': Timestamp.fromDate(DateTime(2026, 10, 20)),
    });
    await db.doc('users/alice/personal_transactions/old').set({
      'amount': 500,
      'type': 'expense',
      'title': 'Old payment',
      'date': Timestamp.fromDate(DateTime(2026, 9, 20)),
    });
    final matches = await repo.possibleMatches('alice', sms);
    expect(matches.map((m) => m.id), ['emi']);
  });
  test(
    'linking a bank alert preserves the original EMI and expense amount',
    () async {
      final target = db.doc('users/alice/personal_transactions/emi');
      await target.set({
        'amount': 500,
        'type': 'expense',
        'title': 'Loan EMI',
        'loanSourceId': 'loan-one',
        'date': Timestamp.fromDate(DateTime(2026, 10, 20)),
        'notes': 'Original loan history',
      });
      await repo.save('alice', sms, existingId: 'emi');
      final data = (await target.get()).data()!;
      expect(data['title'], 'Loan EMI');
      expect(data['amount'], 500);
      expect(data['notes'], 'Original loan history');
      expect(data['loanSourceId'], 'loan-one');
      expect(data['bankReference'], sms.reference);
      expect(
        (await db.collection('users/alice/personal_transactions').get())
            .docs
            .length,
        1,
      );
      expect(await repo.wasRecorded('alice', sms), isTrue);
    },
  );
  test(
    'stale matching transactions cannot be linked with changed amounts',
    () async {
      await db.doc('users/alice/personal_transactions/stale').set({
        'amount': 200,
        'type': 'expense',
      });
      await expectLater(
        repo.save('alice', sms, existingId: 'stale'),
        throwsStateError,
      );
      expect(await repo.wasRecorded('alice', sms), isFalse);
    },
  );
  test('imports are isolated between signed-in accounts', () async {
    await repo.save('alice', sms);
    expect(await repo.wasRecorded('bob', sms), isFalse);
    await repo.save('bob', sms);
    expect(
      (await db.collection('users/bob/personal_transactions').get())
          .docs
          .length,
      1,
    );
  });
  test(
    'reviewed credits and edited dates use the selected month without changing the SMS identity',
    () async {
      await repo.save(
        'alice',
        sms,
        direction: BankSmsDirection.credit,
        amount: 450,
        date: DateTime(2026, 9, 30),
        title: 'Refund',
        category: 'Shopping',
      );
      final data =
          (await db
                  .doc('users/alice/personal_transactions/${sms.transactionId}')
                  .get())
              .data()!;
      expect(data['type'], 'income');
      expect(data['amount'], 450);
      expect(data['month'], '2026-09');
      expect(data['title'], 'Refund');
      expect(data['category'], 'Shopping');
    },
  );
  test(
    'receipt rule from the live rules file restricts access to its owner',
    () async {
      // The fake cannot parse the existing project's rules_version/functions.
      // Test the actual new match block inside its real collection scope.
      final source = File('firestore.rules').readAsStringSync();
      final receiptRule = RegExp(
        r'match /bank_sms_receipts/\{receiptId\} \{[^}]*\}',
      ).firstMatch(source)!.group(0)!;
      final secure = FakeFirebaseFirestore(
        securityRules:
            'service cloud.firestore { match /databases/{database}/documents { match /users/{userId} { $receiptRule } } }',
      );
      secure.authObject.add({
        'uid': 'alice',
        'token': {'email': 'alice@example.com'},
      });
      await secure.doc('users/alice/bank_sms_receipts/test').set({
        'transactionId': 'one',
      });
      expect(
        (await secure.doc('users/alice/bank_sms_receipts/test').get()).exists,
        isTrue,
      );
      await expectLater(
        secure.doc('users/bob/bank_sms_receipts/test').set({
          'transactionId': 'two',
        }),
        throwsException,
      );
      secure.authObject.add(null);
      await expectLater(
        secure.doc('users/alice/bank_sms_receipts/test').get(),
        throwsException,
      );
    },
  );
}
