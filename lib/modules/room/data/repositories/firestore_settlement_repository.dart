import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import 'package:split_ex/shared/data/mappers/settlement_firestore_mapper.dart';
import 'package:split_ex/modules/room/domain/repositories/settlement_repository.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';
import 'firestore_room_ledger_repository.dart';
import 'package:split_ex/modules/room/domain/entities/room_activity_entry.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';

class FirestoreSettlementRepository implements SettlementRepository {
  final RoomFirestoreDataSource _source;
  FirestoreSettlementRepository({RoomFirestoreDataSource? source})
    : _source = source ?? RoomFirestoreDataSource();

  CollectionReference<Map<String, dynamic>> _ref(String roomId) {
    return _source.settlements(roomId);
  }

  Future<String> createSettlement(
    String roomId,
    SettlementModel settlement,
  ) async {
    return FirestoreRoomLedgerRepository(
      firestore: _source.db,
    ).recordSettlement(
      roomId,
      settlement,
      RoomActivityEntry(
        type: ActivityType.settlementCreated,
        performedBy: settlement.fromUserId,
        description: 'Payment recorded',
      ),
    );
  }

  Future<void> confirmSettlement(
    String roomId,
    String settlementId, {
    required String performedBy,
  }) async {
    await FirestoreRoomLedgerRepository(
      firestore: _source.db,
    ).confirmSettlement(
      roomId,
      settlementId,
      RoomActivityEntry(
        type: ActivityType.settlementConfirmed,
        performedBy: performedBy,
        description: 'Payment confirmed',
      ),
    );
  }

  Future<void> cancelSettlement(
    String roomId,
    String settlementId, {
    required String performedBy,
  }) async {
    await _source.db.runTransaction((transaction) async {
      final roomRef = _source.rooms.doc(roomId);
      final room = (await transaction.get(roomRef)).data();
      final ref = _ref(roomId).doc(settlementId);
      final payment = (await transaction.get(ref)).data();
      if (room == null ||
          room['isArchived'] == true ||
          room['isLocked'] == true ||
          payment == null ||
          payment['status'] != 'pending' ||
          payment['fromUserId'] != performedBy ||
          !{
            ...List<String>.from(room['participantIds'] ?? []),
            ...List<String>.from(room['memberIds'] ?? []),
          }.contains(performedBy)) {
        throw Exception(
          'Only a pending payment in an open room can be cancelled.',
        );
      }
      transaction.update(ref, {
        'status': SettlementStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      final nextVersion = (room['ledgerVersion'] as int? ?? 0) + 1;
      transaction.update(roomRef, {'ledgerVersion': nextVersion});
      transaction.set(_source.activities(roomId).doc(), {
        'type': ActivityType.roomSettingsChanged.name,
        'performedBy': performedBy,
        'description': 'Pending payment cancelled',
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {'settlementId': settlementId},
      });
    });
  }

  Future<void> addUpiRef(
    String roomId,
    String settlementId,
    String upiRef, {
    required String performedBy,
  }) async {
    await _source.writeOpenLedger(roomId, (transaction) async {
      final payment = (await transaction.get(
        _ref(roomId).doc(settlementId),
      )).data();
      if (payment == null ||
          payment['fromUserId'] != performedBy ||
          payment['status'] != 'pending') {
        throw Exception(
          'Only the payer can update a pending payment reference.',
        );
      }
      transaction.update(_ref(roomId).doc(settlementId), {'upiRef': upiRef});
    });
  }

  Stream<List<SettlementModel>> getSettlementsStream(String roomId) {
    return _ref(roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SettlementFirestoreMapper.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Stream<List<SettlementModel>> getPendingSettlementsStream(
    String roomId,
    String userId,
  ) {
    return _ref(roomId)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: SettlementStatus.pending.name)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SettlementFirestoreMapper.fromMap(d.data(), d.id))
              .toList(),
        );
  }
}
