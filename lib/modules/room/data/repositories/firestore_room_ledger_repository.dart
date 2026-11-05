import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_activity_entry.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/modules/room/domain/policies/balance_service.dart';
import 'package:split_ex/modules/room/domain/repositories/room_ledger_repository.dart';
import 'package:split_ex/shared/data/mappers/settlement_firestore_mapper.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';

class FirestoreRoomLedgerRepository implements RoomLedgerRepository {
  final FirebaseFirestore firestore;
  late final RoomFirestoreDataSource _source = RoomFirestoreDataSource(
    firestore: firestore,
  );
  final UsageTracker? usageTracker;

  FirestoreRoomLedgerRepository({required this.firestore, this.usageTracker});

  void _amount(double amount) {
    if (!amount.isFinite ||
        amount <= 0 ||
        (amount * 100 - (amount * 100).round()).abs() > 0.000001) {
      throw Exception(
        'Enter a positive amount with at most two decimal places.',
      );
    }
  }

  void _participants(
    RoomModel room,
    String payer,
    List<String> participants, {
    List<String> original = const [],
  }) {
    final allowed = {...room.memberIds, ...original};
    if (!allowed.contains(payer) ||
        participants.isEmpty ||
        participants.toSet().length != participants.length ||
        participants.any((id) => !allowed.contains(id))) {
      throw Exception(
        'Choose valid room participants. Refresh the room and try again.',
      );
    }
  }

  Future<void> _write(
    String roomId,
    RoomActivityEntry activity,
    Future<void> Function(Transaction, RoomModel) write, {
    bool settlement = false,
    int? expectedVersion,
  }) async {
    final roomRef = _source.rooms.doc(roomId);
    await firestore.runTransaction((transaction) async {
      final doc = await transaction.get(roomRef);
      final data = doc.data();
      if (data == null) throw Exception('Room not found.');
      final room = RoomFirestoreMapper.fromMap(data, roomId);
      if (room.isArchived ||
          room.isLocked ||
          !(settlement
              ? room.canRead(activity.performedBy)
              : room.isMember(activity.performedBy))) {
        throw Exception('This room is read-only for you.');
      }
      if (expectedVersion != null &&
          (data['ledgerVersion'] ?? 0) != expectedVersion) {
        throw Exception('The room changed. Refresh and try again.');
      }
      await write(transaction, room);
      transaction.update(roomRef, {'ledgerVersion': FieldValue.increment(1)});
      transaction.set(_source.activities(roomId).doc(), {
        'type': activity.type.name,
        'performedBy': activity.performedBy,
        'description': activity.description,
        'createdAt': FieldValue.serverTimestamp(),
        if (activity.metadata != null) 'metadata': activity.metadata,
      });
    });
  }

  @override
  Future<void> recordExpense(
    String roomId,
    ExpenseModel expense,
    RoomActivityEntry activity,
  ) async {
    _amount(expense.amount);
    if (expense.createdBy != activity.performedBy ||
        expense.title.trim().isEmpty) {
      throw Exception('Invalid expense.');
    }
    final ref = _source.expenses(roomId).doc();
    await _write(roomId, activity, (transaction, room) async {
      _participants(room, expense.paidBy, expense.splitAmong);
      transaction.set(ref, ExpenseFirestoreMapper.toMap(expense));
    });
    await usageTracker?.trackWrites(1);
  }

  @override
  Future<void> editExpense(
    String roomId,
    String expenseId,
    RoomExpenseUpdate changes,
    RoomActivityEntry activity,
  ) async {
    _amount(changes.amount);
    if (changes.title.trim().isEmpty)
      throw Exception('Enter an expense title.');
    final ref = _source.expenses(roomId).doc(expenseId);
    await _write(roomId, activity, (transaction, room) async {
      final data = (await transaction.get(ref)).data();
      if (data == null) throw Exception('Expense not found.');
      final original = ExpenseFirestoreMapper.fromMap(data, expenseId);
      if (original.createdBy != activity.performedBy &&
          !room.isAdmin(activity.performedBy)) {
        throw Exception('Only the creator or admin can edit this expense.');
      }
      _participants(
        room,
        original.paidBy,
        changes.splitAmong,
        original: [...original.splitAmong, original.paidBy],
      );
      transaction.update(ref, ExpenseFirestoreMapper.toUpdateMap(changes));
    });
    await usageTracker?.trackWrites(1);
  }

  @override
  Future<void> deleteExpense(
    String roomId,
    String expenseId,
    RoomActivityEntry activity,
  ) async {
    final ref = _source.expenses(roomId).doc(expenseId);
    await _write(roomId, activity, (transaction, room) async {
      final data = (await transaction.get(ref)).data();
      if (data == null) throw Exception('Expense not found.');
      if (data['createdBy'] != activity.performedBy &&
          !room.isAdmin(activity.performedBy)) {
        throw Exception('Only the creator or admin can delete this expense.');
      }
      transaction.delete(ref);
    });
    await usageTracker?.trackWrites(1);
  }

  @override
  Future<void> recordBill(
    String roomId,
    BillModel bill,
    RoomActivityEntry activity,
  ) async {
    _amount(bill.amount);
    final ref = _source.bills(roomId).doc();
    await _write(roomId, activity, (transaction, room) async {
      _participants(room, bill.paidBy, bill.splitAmong);
      transaction.set(ref, BillFirestoreMapper.toMap(bill));
    });
  }

  @override
  Future<void> deleteBill(
    String roomId,
    String billId,
    RoomActivityEntry activity,
  ) async {
    final ref = _source.bills(roomId).doc(billId);
    await _write(roomId, activity, (transaction, room) async {
      final data = (await transaction.get(ref)).data();
      if (data == null) throw Exception('Bill not found.');
      if (data['paidBy'] != activity.performedBy &&
          !room.isAdmin(activity.performedBy)) {
        throw Exception('Only the payer or admin can delete this bill.');
      }
      transaction.delete(ref);
    });
  }

  @override
  Future<String> recordSettlement(
    String roomId,
    SettlementModel settlement,
    RoomActivityEntry activity,
  ) async {
    _amount(settlement.amount);
    if (settlement.roomId != roomId ||
        settlement.fromUserId != activity.performedBy ||
        settlement.fromUserId == settlement.toUserId ||
        settlement.status != SettlementStatus.pending) {
      throw Exception(
        'Only the payer can record a pending payment to another participant.',
      );
    }
    // Read the version first. Every ledger/membership mutation increments it;
    // a concurrent write invalidates this projection before the payment is saved.
    final roomDoc = await _source.rooms.doc(roomId).get();
    final data = roomDoc.data();
    if (data == null) throw Exception('Room not found.');
    final month = settlement.effectiveMonth;
    final snapshots = await Future.wait([
      _source.expenses(roomId).where('month', isEqualTo: month).get(),
      _source.bills(roomId).where('month', isEqualTo: month).get(),
      _source.settlements(roomId).get(),
    ]);
    final room = RoomFirestoreMapper.fromMap(data, roomId);
    var outstanding = BalanceService().pairBalance(
      from: settlement.fromUserId,
      to: settlement.toUserId,
      expenses: snapshots[0].docs
          .map((d) => ExpenseFirestoreMapper.fromMap(d.data(), d.id))
          .toList(),
      bills: snapshots[1].docs
          .map((d) => BillFirestoreMapper.fromMap(d.data(), d.id))
          .toList(),
      legacyBillMemberIds: room.billFallbackMemberIds,
    );
    for (final doc in snapshots[2].docs) {
      final payment = SettlementFirestoreMapper.fromMap(doc.data(), doc.id);
      if (payment.effectiveMonth != month ||
          payment.status == SettlementStatus.cancelled)
        continue;
      final samePair =
          (payment.fromUserId == settlement.fromUserId &&
              payment.toUserId == settlement.toUserId) ||
          (payment.fromUserId == settlement.toUserId &&
              payment.toUserId == settlement.fromUserId);
      if (samePair && payment.status == SettlementStatus.pending) {
        throw Exception(
          'A payment between these participants is awaiting confirmation.',
        );
      }
      if (payment.fromUserId == settlement.fromUserId &&
          payment.toUserId == settlement.toUserId)
        outstanding -= payment.amount;
      if (payment.fromUserId == settlement.toUserId &&
          payment.toUserId == settlement.fromUserId &&
          payment.status == SettlementStatus.confirmed)
        outstanding += payment.amount;
    }
    if (settlement.amount - outstanding > 0.005) {
      throw Exception(
        'This amount exceeds the unpaid balance, or a payment is already pending.',
      );
    }
    final ref = _source.settlements(roomId).doc();
    await _write(
      roomId,
      activity,
      (transaction, current) async {
        if (!current.canRead(settlement.toUserId))
          throw Exception('Payee is not a room participant.');
        transaction.set(ref, {
          ...SettlementFirestoreMapper.toMap(settlement),
          'ledgerMonth': month,
        });
      },
      settlement: true,
      expectedVersion: (data['ledgerVersion'] as num?)?.toInt() ?? 0,
    );
    return ref.id;
  }

  @override
  Future<void> confirmSettlement(
    String roomId,
    String settlementId,
    RoomActivityEntry activity,
  ) async {
    final ref = _source.settlements(roomId).doc(settlementId);
    await _write(roomId, activity, (transaction, room) async {
      final data = (await transaction.get(ref)).data();
      if (data == null ||
          data['toUserId'] != activity.performedBy ||
          data['status'] != 'pending') {
        throw Exception('Only the recipient can confirm a pending payment.');
      }
      transaction.update(ref, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });
    }, settlement: true);
  }
}
