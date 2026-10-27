import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_recurring_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_edit.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_entry.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestorePersonalRecurringRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    repository = FirestorePersonalRecurringRepository(firestore: db);
  });

  PersonalRecurringEntry entry() => const PersonalRecurringEntry(
    id: '',
    title: 'Rent',
    amount: 100,
    category: 'Rent',
    type: TransactionType.expense,
    frequency: PersonalRecurringFrequency.monthly,
    dayOfMonth: 5,
    active: true,
    userId: 'alice',
  );

  test(
    'add, edit history, pause and delete retain the stored schema',
    () async {
      await repository.add('alice', entry());
      final current = (await repository.entries('alice').first).single;
      final ref = db.doc('users/alice/personal_recurring/${current.id}');
      final created = (await ref.get()).data()!;
      expect(created['createdAt'], isA<Timestamp>());
      expect(created['frequency'], 'monthly');
      expect(created['editHistory'], isEmpty);

      await repository.update(
        'alice',
        current,
        const PersonalRecurringChanges(
          title: 'Rent increase',
          amount: 120,
          frequency: PersonalRecurringFrequency.weekly,
        ),
      );
      final updated = (await ref.get()).data()!;
      expect(updated['title'], 'Rent increase');
      expect(updated['amount'], 120);
      expect(updated['frequency'], 'weekly');
      expect((updated['editHistory'] as List), hasLength(1));
      final history =
          (await repository.entries('alice').first).single.editHistory;
      expect(history.single.title, 'Rent');
      expect(history.single.editedAt, isA<DateTime>());

      await repository.toggle('alice', current.id, false);
      expect((await repository.entries('alice').first).single.active, isFalse);
      await repository.delete('alice', current.id);
      expect(await repository.entries('alice').first, isEmpty);
    },
  );

  test('old documents default missing recurrence fields', () async {
    await db.doc('users/alice/personal_recurring/old').set({
      'title': 'Old',
      'amount': 20,
      'dayOfMonth': 1,
    });
    final old = (await repository.entries('alice').first).single;
    expect(old.frequency, PersonalRecurringFrequency.monthly);
    expect(old.type, TransactionType.expense);
    expect(old.category, 'Other');
    expect(old.active, isTrue);
  });
}
