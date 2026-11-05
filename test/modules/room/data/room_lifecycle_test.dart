import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_bill_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_room_ledger_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_room_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_settlement_repository.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_activity_entry.dart';
import 'package:split_ex/modules/room/domain/entities/room_bill_update.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/modules/room/domain/policies/balance_service.dart';
import 'package:split_ex/modules/room/domain/use_cases/ensure_room_exit_before_account_deletion.dart';
import 'package:split_ex/shared/data/mappers/settlement_firestore_mapper.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRoomRepository rooms;
  late FirestoreRoomLedgerRepository ledger;
  late FirestoreSettlementRepository payments;
  late String roomId;
  late String code;
  final date = DateTime(2026, 10, 12);

  RoomActivityEntry action(String user, ActivityType type) => RoomActivityEntry(
    type: type,
    performedBy: user,
    description: 'Test action',
  );
  ExpenseModel expense({
    String payer = 'alice',
    double amount = 120,
    List<String> participants = const ['alice', 'bob'],
  }) => ExpenseModel(
    id: '',
    title: 'Dinner',
    amount: amount,
    category: 'Food',
    date: date,
    paidBy: payer,
    splitType: SplitType.equal,
    splitAmong: participants,
    createdBy: payer,
    createdAt: date,
    month: '2026-10',
  );
  BillModel bill({List<String> participants = const ['alice', 'bob']}) =>
      BillModel(
        id: '',
        type: BillType.rent,
        amount: 600,
        splitType: 'equal',
        paidBy: 'alice',
        splitAmong: participants,
        month: '2026-10',
        date: date,
        createdAt: date,
      );
  SettlementModel payment({
    double amount = 60,
    String month = '2026-10',
    String from = 'bob',
    String to = 'alice',
  }) => SettlementModel(
    id: '',
    roomId: roomId,
    fromUserId: from,
    toUserId: to,
    amount: amount,
    createdAt: DateTime(2026, 11, 5),
    ledgerMonth: month,
  );
  Future<RoomModel> readRoom() async {
    final doc = await db.doc('rooms/$roomId').get();
    return RoomFirestoreMapper.fromMap(doc.data()!, roomId);
  }

  Future<Map<String, double>> balances() async {
    final room = await readRoom();
    final expenses = await db.collection('rooms/$roomId/expenses').get();
    final bills = await db.collection('rooms/$roomId/bills').get();
    final settlements = await db.collection('rooms/$roomId/settlements').get();
    return BalanceService().computeNetBalances(
      memberIds: room.historicalMemberIds,
      legacyBillMemberIds: room.billFallbackMemberIds,
      expenses: expenses.docs
          .map((d) => ExpenseFirestoreMapper.fromMap(d.data(), d.id))
          .toList(),
      bills: bills.docs
          .map((d) => BillFirestoreMapper.fromMap(d.data(), d.id))
          .toList(),
      settlements: settlements.docs
          .map((d) => SettlementFirestoreMapper.fromMap(d.data(), d.id))
          .toList(),
    );
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    rooms = FirestoreRoomRepository(firestore: db);
    ledger = FirestoreRoomLedgerRepository(firestore: db);
    payments = FirestoreSettlementRepository(
      source: RoomFirestoreDataSource(firestore: db),
    );
    final room = await rooms.createRoom('Home', 'alice');
    roomId = room.id;
    code = room.inviteCode;
    final joined = await rooms.joinRoom(code, 'bob');
    expect(joined!.memberIds, ['alice', 'bob']);
  });

  test(
    'leaving retains expenses, bills, settlements, names and former room access',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      await ledger.recordBill(
        roomId,
        bill(),
        action('alice', ActivityType.billAdded),
      );
      final id = await ledger.recordSettlement(
        roomId,
        payment(amount: 100),
        action('bob', ActivityType.settlementCreated),
      );
      final before = await balances();
      await rooms.leaveRoom(roomId, 'bob');
      final room = await readRoom();
      expect(room.memberIds, ['alice']);
      expect(room.historicalMemberIds, contains('bob'));
      expect(room.canWrite('bob'), isFalse);
      expect(room.canRead('bob'), isTrue);
      expect(
        (await rooms.getUserRoomsStream('bob').first).map((r) => r.id),
        contains(roomId),
      );
      expect(await balances(), before);
      expect(
        (await db.collection('rooms/$roomId/expenses').get()).docs,
        hasLength(1),
      );
      expect(
        (await db.collection('rooms/$roomId/bills').get()).docs,
        hasLength(1),
      );
      expect(
        (await db.doc('rooms/$roomId/settlements/$id').get()).exists,
        isTrue,
      );
    },
  );

  test(
    'newcomer does not inherit an old bill; old shares survive another departure',
    () async {
      await ledger.recordBill(
        roomId,
        bill(),
        action('alice', ActivityType.billAdded),
      );
      await rooms.joinRoom(code, 'carol');
      expect(await balances(), {'alice': 300, 'bob': -300, 'carol': 0});
      await rooms.leaveRoom(roomId, 'bob');
      expect(await balances(), {'alice': 300, 'bob': -300, 'carol': 0});
    },
  );

  test(
    'legacy empty bill participants are frozen before membership changes',
    () async {
      await db.doc('rooms/$roomId').update({
        'legacyBillMemberIds': FieldValue.delete(),
      });
      await db
          .doc('rooms/$roomId/bills/legacy')
          .set(BillFirestoreMapper.toMap(bill(participants: [])));
      await rooms.joinRoom(code, 'carol');
      await rooms.leaveRoom(roomId, 'bob');
      expect(await balances(), {'alice': 300, 'bob': -300, 'carol': 0});
    },
  );

  test(
    'admin must hand over before leaving and transfer preserves the ledger',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      await expectLater(rooms.leaveRoom(roomId, 'alice'), throwsException);
      expect((await readRoom()).memberIds, ['alice', 'bob']);
      await rooms.transferAdmin(roomId, 'alice', 'bob');
      await rooms.leaveRoom(roomId, 'alice');
      final room = await readRoom();
      expect(room.adminId, 'bob');
      expect(room.memberIds, ['bob']);
      expect(await balances(), {'alice': 60, 'bob': -60});
    },
  );

  test(
    'non-admin and inactive successor cannot take ownership or remove others',
    () async {
      await expectLater(
        rooms.transferAdmin(roomId, 'bob', 'alice'),
        throwsException,
      );
      await expectLater(
        rooms.transferAdmin(roomId, 'alice', 'outsider'),
        throwsException,
      );
      await expectLater(
        rooms.removeMember(roomId, 'alice', performedBy: 'bob'),
        throwsException,
      );
      expect((await readRoom()).adminId, 'alice');
    },
  );

  test(
    'admin removal keeps former participant and removes only the active backlink',
    () async {
      await rooms.removeMember(roomId, 'bob', performedBy: 'alice');
      final room = await readRoom();
      expect(room.memberIds, ['alice']);
      expect(room.historicalMemberIds, contains('bob'));
      expect((await db.doc('users/bob').get()).data()!['rooms'], isEmpty);
      expect((await rooms.getUserRoomsStream('bob').first), hasLength(1));
    },
  );

  test(
    'rejoining is idempotent and never duplicates historical participants',
    () async {
      await rooms.leaveRoom(roomId, 'bob');
      await rooms.joinRoom(code, 'bob');
      await rooms.joinRoom(code, 'bob');
      final room = await readRoom();
      expect(room.memberIds, ['alice', 'bob']);
      expect(room.historicalMemberIds.toSet(), {'alice', 'bob'});
    },
  );

  test(
    'archive is admin-only and blocks joining and every ledger entry',
    () async {
      await expectLater(
        rooms.setArchived(roomId, 'bob', true),
        throwsException,
      );
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      final before = await balances();
      await rooms.setArchived(roomId, 'alice', true);
      expect((await readRoom()).isArchived, isTrue);
      await expectLater(rooms.joinRoom(code, 'carol'), throwsException);
      await expectLater(
        ledger.recordExpense(
          roomId,
          expense(),
          action('alice', ActivityType.expenseAdded),
        ),
        throwsException,
      );
      await expectLater(
        ledger.recordBill(
          roomId,
          bill(),
          action('alice', ActivityType.billAdded),
        ),
        throwsException,
      );
      await expectLater(
        ledger.recordSettlement(
          roomId,
          payment(),
          action('bob', ActivityType.settlementCreated),
        ),
        throwsException,
      );
      expect(await balances(), before);
      await rooms.setArchived(roomId, 'alice', false);
      await ledger.recordSettlement(
        roomId,
        payment(),
        action('bob', ActivityType.settlementCreated),
      );
    },
  );

  test(
    'last departure archives the room; former admin can restore and rejoin',
    () async {
      await rooms.leaveRoom(roomId, 'bob');
      await rooms.leaveRoom(roomId, 'alice');
      final archived = await readRoom();
      expect(archived.isArchived, isTrue);
      expect(archived.memberIds, isEmpty);
      expect((await rooms.getUserRoomsStream('alice').first), hasLength(1));
      await rooms.setArchived(roomId, 'alice', false);
      final restored = await readRoom();
      expect(restored.isArchived, isFalse);
      expect(restored.memberIds, ['alice']);
      expect((await db.doc('users/alice').get()).data()!['rooms'], [roomId]);
    },
  );

  test('departed debtor can pay and departed creditor can confirm', () async {
    await ledger.recordExpense(
      roomId,
      expense(),
      action('alice', ActivityType.expenseAdded),
    );
    await rooms.leaveRoom(roomId, 'bob');
    final id = await ledger.recordSettlement(
      roomId,
      payment(),
      action('bob', ActivityType.settlementCreated),
    );
    expect(await balances(), {'alice': 60, 'bob': -60});
    await rooms.leaveRoom(roomId, 'alice');
    await rooms.setArchived(roomId, 'alice', false);
    await ledger.confirmSettlement(
      roomId,
      id,
      action('alice', ActivityType.settlementConfirmed),
    );
    expect(await balances(), {'alice': 0, 'bob': 0});
  });

  test(
    'only recipient can confirm; confirmation is a single pending transition',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      final id = await ledger.recordSettlement(
        roomId,
        payment(),
        action('bob', ActivityType.settlementCreated),
      );
      await expectLater(
        ledger.confirmSettlement(
          roomId,
          id,
          action('bob', ActivityType.settlementConfirmed),
        ),
        throwsException,
      );
      await ledger.confirmSettlement(
        roomId,
        id,
        action('alice', ActivityType.settlementConfirmed),
      );
      await expectLater(
        ledger.confirmSettlement(
          roomId,
          id,
          action('alice', ActivityType.settlementConfirmed),
        ),
        throwsException,
      );
      await expectLater(
        payments.cancelSettlement(roomId, id, performedBy: 'bob'),
        throwsException,
      );
      expect(await balances(), {'alice': 0, 'bob': 0});
    },
  );

  test(
    'pending payments reserve the balance; cancelled payments release it',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      final id = await ledger.recordSettlement(
        roomId,
        payment(),
        action('bob', ActivityType.settlementCreated),
      );
      await expectLater(
        ledger.recordSettlement(
          roomId,
          payment(),
          action('bob', ActivityType.settlementCreated),
        ),
        throwsException,
      );
      await expectLater(
        payments.cancelSettlement(roomId, id, performedBy: 'alice'),
        throwsException,
      );
      await payments.cancelSettlement(roomId, id, performedBy: 'bob');
      await ledger.recordSettlement(
        roomId,
        payment(),
        action('bob', ActivityType.settlementCreated),
      );
      expect(await balances(), {'alice': 60, 'bob': -60});
    },
  );

  test(
    'later payment settles the selected expense month and cannot repeat',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      await expectLater(
        ledger.recordSettlement(
          roomId,
          payment(month: '2026-11'),
          action('bob', ActivityType.settlementCreated),
        ),
        throwsException,
      );
      final id = await ledger.recordSettlement(
        roomId,
        payment(),
        action('bob', ActivityType.settlementCreated),
      );
      await ledger.confirmSettlement(
        roomId,
        id,
        action('alice', ActivityType.settlementConfirmed),
      );
      final stored = (await db.doc('rooms/$roomId/settlements/$id').get())
          .data()!;
      expect(stored['ledgerMonth'], '2026-10');
      await expectLater(
        ledger.recordSettlement(
          roomId,
          payment(),
          action('bob', ActivityType.settlementCreated),
        ),
        throwsException,
      );
    },
  );

  test(
    'new entries reject departed members and invalid monetary values',
    () async {
      await rooms.leaveRoom(roomId, 'bob');
      await expectLater(
        ledger.recordExpense(
          roomId,
          expense(payer: 'bob'),
          action('bob', ActivityType.expenseAdded),
        ),
        throwsException,
      );
      await expectLater(
        ledger.recordExpense(
          roomId,
          expense(),
          action('alice', ActivityType.expenseAdded),
        ),
        throwsException,
      );
      for (final amount in [0.0, -1.0, double.nan, double.infinity, 1.001]) {
        await expectLater(
          ledger.recordExpense(
            roomId,
            expense(amount: amount, participants: ['alice']),
            action('alice', ActivityType.expenseAdded),
          ),
          throwsException,
        );
      }
      expect(
        (await db.collection('rooms/$roomId/expenses').get()).docs,
        isEmpty,
      );
    },
  );

  test(
    'active admin can correct an old expense without erasing its former participants',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(payer: 'bob'),
        action('bob', ActivityType.expenseAdded),
      );
      final id =
          (await db.collection('rooms/$roomId/expenses').get()).docs.single.id;
      await rooms.leaveRoom(roomId, 'bob');
      await ledger.editExpense(
        roomId,
        id,
        RoomExpenseUpdate(
          title: 'Corrected dinner',
          amount: 140,
          category: 'Food',
          date: date,
          splitType: SplitType.equal,
          splitAmong: ['alice', 'bob'],
          month: '2026-10',
        ),
        action('alice', ActivityType.expenseEdited),
      );
      expect(await balances(), {'alice': -70, 'bob': 70});
      await expectLater(
        ledger.deleteExpense(
          roomId,
          id,
          action('bob', ActivityType.expenseDeleted),
        ),
        throwsException,
      );
    },
  );

  test(
    'archived bill edit and deletion fail without removing the original',
    () async {
      await ledger.recordBill(
        roomId,
        bill(),
        action('alice', ActivityType.billAdded),
      );
      final id =
          (await db.collection('rooms/$roomId/bills').get()).docs.single.id;
      await rooms.setArchived(roomId, 'alice', true);
      final repository = FirestoreBillRepository(
        source: RoomFirestoreDataSource(firestore: db),
      );
      await expectLater(
        repository.updateBill(
          roomId,
          id,
          RoomBillUpdate(
            type: BillType.rent,
            amount: 700,
            date: date,
            month: '2026-10',
          ),
          performedBy: 'alice',
        ),
        throwsException,
      );
      await expectLater(
        ledger.deleteBill(
          roomId,
          id,
          action('alice', ActivityType.billDeleted),
        ),
        throwsException,
      );
      expect(
        (await db.doc('rooms/$roomId/bills/$id').get()).data()!['amount'],
        600,
      );
    },
  );

  test(
    'account deletion requires leaving active rooms and preserves historical rooms',
    () async {
      final guard = EnsureRoomExitBeforeAccountDeletion(rooms);
      await expectLater(guard('bob'), throwsException);
      await rooms.leaveRoom(roomId, 'bob');
      await guard('bob');
      await expectLater(guard('alice'), throwsException);
      await rooms.leaveRoom(roomId, 'alice');
      await guard('alice');
      expect((await readRoom()).isArchived, isTrue);
    },
  );

  test(
    'room discovery handles legacy membership and puts active rooms before history',
    () async {
      await rooms.setArchived(roomId, 'alice', true);
      await db.doc('rooms/legacy').set({
        'name': 'Old schema',
        'adminId': 'bob',
        'memberIds': ['bob'],
      });
      final discovered = await rooms.getUserRoomsStream('bob').first;
      expect(discovered.map((r) => r.id), ['legacy', roomId]);
    },
  );

  test(
    'admin can recover legacy departed participants from stored ledger snapshots',
    () async {
      await ledger.recordExpense(
        roomId,
        expense(),
        action('alice', ActivityType.expenseAdded),
      );
      await db.doc('rooms/$roomId').update({
        'memberIds': ['alice'],
        'participantIds': ['alice'],
      });
      await rooms.restoreHistoricalParticipants(roomId, 'alice');
      final restored = await readRoom();
      expect(restored.memberIds, ['alice']);
      expect(restored.historicalMemberIds, contains('bob'));
      expect(
        (await rooms.getUserRoomsStream('bob').first).map((r) => r.id),
        contains(roomId),
      );
      expect(
        (await db.collection('rooms/$roomId/expenses').get()).docs.single
            .data()['amount'],
        120,
      );
    },
  );
}
