import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_activity_entry.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/modules/room/domain/repositories/room_ledger_repository.dart';
import 'package:split_ex/modules/room/domain/repositories/room_repository.dart';
import 'package:split_ex/modules/room/domain/use_cases/confirm_room_settlement.dart';
import 'package:split_ex/modules/room/domain/use_cases/join_room.dart';
import 'package:split_ex/modules/room/domain/use_cases/record_room_expense.dart';
import 'package:split_ex/modules/room/domain/use_cases/record_room_settlement.dart';
import 'package:split_ex/shared/data/mappers/settlement_firestore_mapper.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

class _Ledger implements RoomLedgerRepository {
  final calls = <String>[];
  RoomActivityEntry? activity;

  @override
  Future<void> recordExpense(
    String roomId,
    ExpenseModel expense,
    RoomActivityEntry activity,
  ) async {
    calls.add('expense:$roomId');
    this.activity = activity;
  }

  @override
  Future<String> recordSettlement(
    String roomId,
    SettlementModel settlement,
    RoomActivityEntry activity,
  ) async {
    calls.add('create:$roomId');
    this.activity = activity;
    return 'new-id';
  }

  @override
  Future<void> confirmSettlement(
    String roomId,
    String settlementId,
    RoomActivityEntry activity,
  ) async {
    calls.add('confirm:$settlementId');
    this.activity = activity;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rooms implements RoomRepository {
  String? inviteCode;
  String? userId;

  @override
  Future<RoomModel?> joinRoom(String inviteCode, String userId) async {
    this.inviteCode = inviteCode;
    this.userId = userId;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final date = DateTime(2026, 10, 29);

  test('join workflow normalizes invite code before lookup', () async {
    final rooms = _Rooms();
    await JoinRoom(rooms)(' ab12cd ', 'member-1');
    expect(rooms.inviteCode, 'AB12CD');
    expect(rooms.userId, 'member-1');
  });

  test(
    'expense workflow supplies the ledger with the existing activity payload',
    () async {
      final ledger = _Ledger();
      final expense = ExpenseModel(
        id: '',
        title: 'Dinner',
        amount: 500,
        category: 'Food',
        date: date,
        paidBy: 'a',
        splitType: SplitType.equal,
        splitAmong: const ['a', 'b'],
        createdBy: 'a',
        createdAt: date,
        month: '2026-10',
      );

      await RecordRoomExpense(ledger)('room-1', expense);
      expect(ledger.calls, ['expense:room-1']);
      expect(ledger.activity?.type, ActivityType.expenseAdded);
      expect(ledger.activity?.metadata?['splitAmong'], ['a', 'b']);
      expect(ledger.activity?.metadata?['date'], '29 Oct 2026');
    },
  );

  test(
    'settlement workflows pass the original metadata through the ledger',
    () async {
      final ledger = _Ledger();
      final settlement = SettlementModel(
        id: 's1',
        roomId: 'r1',
        fromUserId: 'a',
        toUserId: 'b',
        amount: 250,
        createdAt: date,
      );

      final id = await RecordRoomSettlement(ledger)(
        'r1',
        settlement,
        payerName: 'A',
        payeeName: 'B',
      );
      expect(id, 'new-id');
      expect(ledger.activity?.type, ActivityType.settlementCreated);
      expect(ledger.activity?.metadata?['from'], 'a');

      await ConfirmRoomSettlement(ledger)(
        'r1',
        settlement,
        'b',
        payerName: 'A',
        payeeName: 'B',
      );
      expect(ledger.calls, ['create:r1', 'confirm:s1']);
      expect(ledger.activity?.type, ActivityType.settlementConfirmed);
      expect(ledger.activity?.metadata?['settlementId'], 's1');
    },
  );

  test('shared settlement mapper preserves the existing Firestore shape', () {
    final settlement = SettlementModel(
      id: 's1',
      roomId: 'r1',
      fromUserId: 'a',
      toUserId: 'b',
      amount: 250,
      createdAt: date,
    );
    final map = SettlementFirestoreMapper.toMap(settlement);
    expect(map['roomId'], 'r1');
    expect(map['status'], 'pending');
    expect(map['createdAt'], isA<FieldValue>());
    final read = SettlementFirestoreMapper.fromMap({
      ...map,
      'createdAt': Timestamp.fromDate(date),
      'confirmedAt': Timestamp.fromDate(date),
      'status': 'confirmed',
    }, 's1');
    expect(read.status, SettlementStatus.confirmed);
    expect(read.createdAt, date);
    expect(read.confirmedAt, date);
  });
}
