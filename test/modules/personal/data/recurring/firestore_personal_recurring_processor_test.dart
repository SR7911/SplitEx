import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/processors/firestore_personal_recurring_processor.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_transaction_repository.dart';

void main() {
  test('app-open processor creates due entry and advances last run', () async {
    SharedPreferences.setMockInitialValues({});
    final db = FakeFirebaseFirestore();
    final recurring = db.doc('users/alice/personal_recurring/rent');
    await recurring.set({
      'title': 'Rent',
      'amount': 100,
      'category': 'Rent',
      'type': 'expense',
      'frequency': 'weekly',
      'dayOfMonth': 1,
      'active': true,
      'userId': 'alice',
      'lastRunDate': Timestamp.fromDate(DateTime(2025, 8, 13)),
    });
    final processor = FirestorePersonalRecurringProcessor(
      firestore: db,
      transactions: FirestorePersonalTransactionRepository(firestore: db),
      clock: () => DateTime(2025, 8, 20, 9),
    );

    await processor.processRecurring('alice');
    await processor.processRecurring('alice');

    final transactions =
        (await db.collection('users/alice/personal_transactions').get()).docs;
    expect(transactions, hasLength(1));
    expect(transactions.single.data()['title'], 'Rent (auto)');
    expect(transactions.single.data()['month'], '2025-08');
    expect(transactions.single.data()['partialSettlements'], isEmpty);
    expect((await recurring.get()).data()!['lastRunDate'], isA<Timestamp>());
  });
}
