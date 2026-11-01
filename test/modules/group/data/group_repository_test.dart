import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/group/data/models/group_firestore_models.dart';
import 'package:split_ex/modules/group/data/repositories/firestore_group_repositories.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_model.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_update.dart';
import 'package:split_ex/modules/group/domain/policies/group_balance_calculator.dart';
import 'package:split_ex/modules/group/domain/use_cases/join_group.dart';
import 'package:split_ex/modules/group/domain/use_cases/save_group_expense.dart';
import 'package:split_ex/modules/group/domain/use_cases/record_group_settlement.dart';
import 'package:split_ex/shared/domain/entities/debt.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreGroupRepository groups;
  late FirestoreGroupExpenseRepository expenses;
  final date = DateTime(2026, 10, 29);

  setUp(() {
    db = FakeFirebaseFirestore();
    groups = FirestoreGroupRepository(firestore: db);
    expenses = FirestoreGroupExpenseRepository(firestore: db);
  });

  test('group membership and status retain their Firestore schema', () async {
    final group = await groups.createGroup(
      name: 'Trip',
      startDate: date,
      createdBy: 'alice',
    );
    final stored = await db.collection('groups').doc(group.id).get();
    expect(stored.data()?['memberIds'], ['alice']);
    expect(stored.data()?['status'], 'active');
    expect(stored.data()?['startDate'], isA<Timestamp>());

    await JoinGroup(groups)(group.inviteCode.toLowerCase(), 'bob');
    expect(
      (await db.collection('groups').doc(group.id).get()).data()?['memberIds'],
      ['alice', 'bob'],
    );
    await groups.archiveGroup(group.id);
    expect((await groups.getGroupStream(group.id).first)?.isArchived, isTrue);
  });

  test(
    'expense mapping and typed edit preserve custom shares and dates',
    () async {
      final group = await groups.createGroup(
        name: 'Trip',
        startDate: date,
        createdBy: 'alice',
      );
      final expense = GroupExpenseModel(
        id: '',
        groupId: group.id,
        title: 'Hotel',
        amount: 300,
        category: 'Hotel',
        paidBy: 'alice',
        splitType: GroupSplitType.custom,
        splitAmong: const ['alice', 'bob'],
        customSplits: const {'alice': 100, 'bob': 200},
        date: date,
        createdBy: 'alice',
        createdAt: date,
      );
      final saved = await expenses.addExpense(expense);
      final stored = await db
          .doc('groups/${group.id}/expenses/${saved.id}')
          .get();
      expect(stored.data()?['customSplits'], {'alice': 100, 'bob': 200});
      expect(stored.data()?['date'], isA<Timestamp>());

      final read = GroupExpenseFirestoreMapper.fromMap(
        stored.data()!,
        saved.id,
      );
      expect(read.shareFor('bob'), 200);
      expect(
        GroupBalanceCalculator().computeNetBalances(
          expenses: [read],
          memberIds: ['alice', 'bob'],
        ),
        {'alice': 200, 'bob': -200},
      );

      await expenses.updateExpense(
        group.id,
        saved.id,
        GroupExpenseUpdate(
          title: 'Hotel room',
          amount: 320,
          category: 'Hotel',
          paidBy: 'alice',
          splitType: GroupSplitType.custom,
          splitAmong: const ['alice', 'bob'],
          customSplits: const {'alice': 120, 'bob': 200},
          date: date,
        ),
      );
      final edited = await db
          .doc('groups/${group.id}/expenses/${saved.id}')
          .get();
      expect(edited.data()?['title'], 'Hotel room');
      expect(edited.data()?['updatedAt'], isA<Timestamp>());
      expect(
        GroupExpenseFirestoreMapper.fromMap(
          edited.data()!,
          saved.id,
        ).shareFor('bob'),
        200,
      );
    },
  );

  test('Group use cases join, save and record a settlement', () async {
    final group = await groups.createGroup(
      name: 'Trip',
      startDate: date,
      createdBy: 'alice',
    );
    final joined = await JoinGroup(groups)(
      ' ${group.inviteCode.toLowerCase()} ',
      'bob',
    );
    expect(joined?.memberIds, ['alice', 'bob']);

    final save = SaveGroupExpense(expenses);
    await save(
      groupId: group.id,
      userId: 'alice',
      changes: GroupExpenseUpdate(
        title: 'Taxi',
        amount: 100,
        category: 'Transport',
        paidBy: 'alice',
        splitType: GroupSplitType.equal,
        splitAmong: const ['alice', 'bob'],
        date: date,
      ),
    );
    final saved =
        (await db.collection('groups/${group.id}/expenses').get()).docs.single;
    expect(saved.data()['title'], 'Taxi');
    await save(
      groupId: group.id,
      userId: 'alice',
      existing: GroupExpenseFirestoreMapper.fromMap(saved.data(), saved.id),
      changes: GroupExpenseUpdate(
        title: 'Train',
        amount: 100,
        category: 'Transport',
        paidBy: 'alice',
        splitType: GroupSplitType.equal,
        splitAmong: const ['alice', 'bob'],
        date: date,
      ),
    );
    expect(
      (await db.doc('groups/${group.id}/expenses/${saved.id}').get())
          .data()?['title'],
      'Train',
    );

    await RecordGroupSettlement(
      FirestoreGroupSettlementRepository(firestore: db),
    )(group.id, const Debt(from: 'bob', to: 'alice', amount: 50));
    final settlement =
        (await db.collection('groups/${group.id}/settlements').get())
            .docs
            .single;
    expect(settlement.data()['fromUserId'], 'bob');
    expect(settlement.data()['roomId'], group.id);
  });

  test(
    'Group expense stream keeps newest date first without query ordering',
    () async {
      final group = await groups.createGroup(
        name: 'Trip',
        startDate: date,
        createdBy: 'alice',
      );
      for (final entry in [
        (title: 'Older', date: DateTime(2026, 10, 1)),
        (title: 'Newer', date: DateTime(2026, 10, 29)),
      ]) {
        await expenses.addExpense(
          GroupExpenseModel(
            id: '',
            groupId: group.id,
            title: entry.title,
            amount: 10,
            category: 'Other',
            paidBy: 'alice',
            splitType: GroupSplitType.equal,
            splitAmong: const ['alice'],
            date: entry.date,
            createdBy: 'alice',
            createdAt: date,
          ),
        );
      }
      final list = await expenses.getExpensesStream(group.id).first;
      expect(list.map((expense) => expense.title), ['Newer', 'Older']);
    },
  );
}
