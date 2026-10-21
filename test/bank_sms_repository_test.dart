import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/services/bank_sms_parser.dart';
import 'package:split_ex/services/bank_sms_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late BankSmsRepository repo;
  final sms = BankSmsParser().parse(
    id: 'sms-one',
    sender: 'VM-TESTBK',
    body:
        'INR 500 debited from A/c XX1234 to SHOP on 20/10/2026 UPI Ref 629300123456.',
    receivedAt: DateTime(2026, 10, 20, 12),
  )!;
  setUp(() {
    db = FakeFirebaseFirestore();
    repo = BankSmsRepository(firestore: db);
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
