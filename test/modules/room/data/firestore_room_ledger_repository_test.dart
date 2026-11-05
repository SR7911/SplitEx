import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_room_ledger_repository.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_activity_entry.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRoomLedgerRepository ledger;
  final date = DateTime(2026, 10, 29);

  setUp(() async {
    db = FakeFirebaseFirestore();
    ledger = FirestoreRoomLedgerRepository(firestore: db);
    await db.doc('rooms/room-1').set({
      'adminId': 'alice',
      'memberIds': ['alice', 'bob'],
      'participantIds': ['alice', 'bob'],
    });
  });

  const added = RoomActivityEntry(
    type: ActivityType.expenseAdded,
    performedBy: 'alice',
    description: 'Added dinner',
    metadata: {'amount': 400},
  );

  test(
    'expense and activity are committed together with existing schema',
    () async {
      final expense = ExpenseModel(
        id: '',
        title: 'Dinner',
        amount: 400,
        category: 'Food',
        date: date,
        paidBy: 'alice',
        splitType: SplitType.equal,
        splitAmong: const ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: date,
        month: '2026-10',
      );
      await ledger.recordExpense('room-1', expense, added);

      final expenses = await db.collection('rooms/room-1/expenses').get();
      final activities = await db.collection('rooms/room-1/activities').get();
      expect(expenses.docs, hasLength(1));
      expect(activities.docs, hasLength(1));
      expect(expenses.docs.single.data()['amount'], 400);
      expect(expenses.docs.single.data()['splitType'], 'equal');
      expect(activities.docs.single.data()['type'], 'expenseAdded');
      expect(activities.docs.single.data()['metadata'], {'amount': 400});

      final id = expenses.docs.single.id;
      await ledger.editExpense(
        'room-1',
        id,
        RoomExpenseUpdate(
          title: 'Lunch',
          amount: 300,
          category: 'Food',
          date: date,
          splitType: SplitType.equal,
          splitAmong: const ['alice', 'bob'],
          month: '2026-10',
        ),
        const RoomActivityEntry(
          type: ActivityType.expenseEdited,
          performedBy: 'alice',
          description: 'Edited lunch',
        ),
      );
      final edited = await db.doc('rooms/room-1/expenses/$id').get();
      expect(edited.data()?['title'], 'Lunch');
      expect(
        (await db.collection('rooms/room-1/activities').get()).docs,
        hasLength(2),
      );

      await ledger.deleteExpense(
        'room-1',
        id,
        const RoomActivityEntry(
          type: ActivityType.expenseDeleted,
          performedBy: 'alice',
          description: 'Deleted lunch',
        ),
      );
      expect(
        (await db.collection('rooms/room-1/expenses').get()).docs,
        isEmpty,
      );
      expect(
        (await db.collection('rooms/room-1/activities').get()).docs,
        hasLength(3),
      );
    },
  );

  test('failed expense update does not leave an orphan activity', () async {
    final update = RoomExpenseUpdate(
      title: 'Missing',
      amount: 1,
      category: 'Other',
      date: date,
      splitType: SplitType.equal,
      splitAmong: const ['alice'],
      month: '2026-10',
    );
    await expectLater(
      ledger.editExpense('room-1', 'missing', update, added),
      throwsA(anything),
    );
    expect(
      (await db.collection('rooms/room-1/activities').get()).docs,
      isEmpty,
    );
  });

  test('bill creation and deletion each commit an activity', () async {
    final bill = BillModel(
      id: '',
      type: BillType.rent,
      amount: 10000,
      splitType: 'equal',
      paidBy: 'alice',
      splitAmong: const ['alice', 'bob'],
      month: '2026-10',
      date: date,
      createdAt: date,
    );
    const activity = RoomActivityEntry(
      type: ActivityType.billAdded,
      performedBy: 'alice',
      description: 'Added rent',
    );

    await ledger.recordBill('room-1', bill, activity);
    final bills = await db.collection('rooms/room-1/bills').get();
    expect(bills.docs, hasLength(1));
    expect(bills.docs.single.data()['type'], 'rent');
    expect(
      (await db.collection('rooms/room-1/activities').get()).docs,
      hasLength(1),
    );

    await ledger.deleteBill(
      'room-1',
      bills.docs.single.id,
      const RoomActivityEntry(
        type: ActivityType.expenseDeleted,
        performedBy: 'alice',
        description: 'Deleted rent',
      ),
    );
    expect((await db.collection('rooms/room-1/bills').get()).docs, isEmpty);
    expect(
      (await db.collection('rooms/room-1/activities').get()).docs,
      hasLength(2),
    );
  });

  test('settlement and confirmation each commit their activity', () async {
    await db.doc('rooms/room-1/expenses/original').set({
      'title': 'Dinner',
      'amount': 400,
      'paidBy': 'bob',
      'splitAmong': ['alice', 'bob'],
      'month': '2026-10',
    });
    final settlement = SettlementModel(
      id: '',
      roomId: 'room-1',
      fromUserId: 'alice',
      toUserId: 'bob',
      amount: 200,
      createdAt: date,
    );
    const created = RoomActivityEntry(
      type: ActivityType.settlementCreated,
      performedBy: 'alice',
      description: 'Paid Bob',
    );
    const confirmed = RoomActivityEntry(
      type: ActivityType.settlementConfirmed,
      performedBy: 'bob',
      description: 'Confirmed payment',
    );

    final id = await ledger.recordSettlement('room-1', settlement, created);
    final stored = await db.doc('rooms/room-1/settlements/$id').get();
    expect(stored.data()?['status'], 'pending');
    expect(
      (await db.collection('rooms/room-1/activities').get()).docs,
      hasLength(1),
    );

    await ledger.confirmSettlement('room-1', id, confirmed);
    final updated = await db.doc('rooms/room-1/settlements/$id').get();
    expect(updated.data()?['status'], 'confirmed');
    expect(updated.data(), contains('confirmedAt'));
    expect(
      (await db.collection('rooms/room-1/activities').get()).docs,
      hasLength(2),
    );
  });
}
