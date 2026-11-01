import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_activity_entry.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/modules/room/domain/repositories/room_ledger_repository.dart';
import 'package:split_ex/shared/data/mappers/settlement_firestore_mapper.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';

class FirestoreRoomLedgerRepository implements RoomLedgerRepository {
  final FirebaseFirestore firestore;
  late final RoomFirestoreDataSource _source = RoomFirestoreDataSource(
    firestore: firestore,
  );
  final UsageTracker? usageTracker;

  FirestoreRoomLedgerRepository({
    required this.firestore,
    UsageTracker? usageTracker,
  }) : usageTracker = usageTracker;

  DocumentReference<Map<String, dynamic>> _room(String roomId) =>
      _source.rooms.doc(roomId);

  void _addActivity(
    WriteBatch batch,
    String roomId,
    RoomActivityEntry activity,
  ) {
    final ref = _room(roomId).collection('activities').doc();
    batch.set(ref, {
      'type': activity.type.name,
      'performedBy': activity.performedBy,
      'description': activity.description,
      'createdAt': FieldValue.serverTimestamp(),
      if (activity.metadata != null) 'metadata': activity.metadata,
    });
  }

  Future<void> _trackExpenseWrite() async {
    await usageTracker?.trackWrites(1);
  }

  @override
  Future<void> recordExpense(
    String roomId,
    ExpenseModel expense,
    RoomActivityEntry activity,
  ) async {
    final batch = firestore.batch();
    batch.set(
      _room(roomId).collection('expenses').doc(),
      ExpenseFirestoreMapper.toMap(expense),
    );
    _addActivity(batch, roomId, activity);
    await batch.commit();
    await _trackExpenseWrite();
  }

  @override
  Future<void> editExpense(
    String roomId,
    String expenseId,
    RoomExpenseUpdate changes,
    RoomActivityEntry activity,
  ) async {
    final batch = firestore.batch();
    batch.update(
      _room(roomId).collection('expenses').doc(expenseId),
      ExpenseFirestoreMapper.toUpdateMap(changes),
    );
    _addActivity(batch, roomId, activity);
    await batch.commit();
    await _trackExpenseWrite();
  }

  @override
  Future<void> deleteExpense(
    String roomId,
    String expenseId,
    RoomActivityEntry activity,
  ) async {
    final batch = firestore.batch();
    batch.delete(_room(roomId).collection('expenses').doc(expenseId));
    _addActivity(batch, roomId, activity);
    await batch.commit();
    await _trackExpenseWrite();
  }

  @override
  Future<void> recordBill(
    String roomId,
    BillModel bill,
    RoomActivityEntry activity,
  ) async {
    final batch = firestore.batch();
    batch.set(
      _room(roomId).collection('bills').doc(),
      BillFirestoreMapper.toMap(bill),
    );
    _addActivity(batch, roomId, activity);
    await batch.commit();
  }

  @override
  Future<void> deleteBill(
    String roomId,
    String billId,
    RoomActivityEntry activity,
  ) async {
    final batch = firestore.batch();
    batch.delete(_room(roomId).collection('bills').doc(billId));
    _addActivity(batch, roomId, activity);
    await batch.commit();
  }

  @override
  Future<String> recordSettlement(
    String roomId,
    SettlementModel settlement,
    RoomActivityEntry activity,
  ) async {
    final ref = _room(roomId).collection('settlements').doc();
    final batch = firestore.batch();
    batch.set(ref, SettlementFirestoreMapper.toMap(settlement));
    _addActivity(batch, roomId, activity);
    await batch.commit();
    return ref.id;
  }

  @override
  Future<void> confirmSettlement(
    String roomId,
    String settlementId,
    RoomActivityEntry activity,
  ) async {
    final batch = firestore.batch();
    batch.update(_room(roomId).collection('settlements').doc(settlementId), {
      'status': SettlementStatus.confirmed.name,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
    _addActivity(batch, roomId, activity);
    await batch.commit();
  }
}
