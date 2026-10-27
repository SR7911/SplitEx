import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_budget_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/budgets/personal_budget.dart';
import 'package:split_ex/modules/personal/domain/use_cases/budgets/save_personal_budget.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestorePersonalBudgetRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    repository = FirestorePersonalBudgetRepository(firestore: db);
  });

  PersonalBudget budget(double amount, {String month = '2025-08'}) =>
      PersonalBudget(
        id: '',
        category: 'Food',
        budget: amount,
        userId: 'alice',
        month: month,
      );

  test(
    'save upserts category and month while reads stay month-scoped',
    () async {
      final save = SavePersonalBudget(repository);
      await save('alice', budget(500));
      await save('alice', budget(650));
      await save('alice', budget(300, month: '2025-09'));

      final august = await repository.budgetsForMonth('alice', '2025-08').first;
      expect(august, hasLength(1));
      expect(august.single.budget, 650);
      expect(august.single.category, 'Food');
      expect(august.single, isA<PersonalBudget>());
      expect(
        await repository.budgetsForMonth('alice', '2025-09').first,
        hasLength(1),
      );

      await repository.delete('alice', august.single.id);
      expect(
        await repository.budgetsForMonth('alice', '2025-08').first,
        isEmpty,
      );
    },
  );

  test('use case rejects invalid amounts without writing', () async {
    final save = SavePersonalBudget(repository);
    await expectLater(save('alice', budget(0)), throwsStateError);
    await expectLater(save('alice', budget(double.nan)), throwsStateError);
    expect(await repository.budgetsForMonth('alice', '2025-08').first, isEmpty);
  });

  test('budget repository uses the existing document schema', () async {
    await repository.save(
      'alice',
      const PersonalBudget(
        id: '',
        category: 'Food',
        budget: 750,
        userId: 'alice',
        month: '2025-08',
      ),
    );
    final data = (await db.collection('users/alice/personal_budgets').get())
        .docs
        .single
        .data();
    expect(data, {
      'category': 'Food',
      'budget': 750.0,
      'userId': 'alice',
      'month': '2025-08',
    });
  });
}
