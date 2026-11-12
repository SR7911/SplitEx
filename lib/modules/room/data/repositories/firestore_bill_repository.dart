import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/domain/repositories/bill_repository.dart';
import 'package:split_ex/modules/room/domain/entities/room_bill_update.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';

class FirestoreBillRepository implements BillRepository {
  final RoomFirestoreDataSource _source;
  FirestoreBillRepository({RoomFirestoreDataSource? source})
    : _source = source ?? RoomFirestoreDataSource();

  CollectionReference<Map<String, dynamic>> _ref(String roomId) {
    return _source.bills(roomId);
  }

  Future<void> addBill(String roomId, BillModel bill) async {
    await _source.writeOpenLedger(roomId, (transaction) async {
      transaction.set(_ref(roomId).doc(), BillFirestoreMapper.toMap(bill));
    });
  }

  Future<void> updateBill(
    String roomId,
    String billId,
    RoomBillUpdate changes, {
    required String performedBy,
  }) async {
    if (!changes.amount.isFinite ||
        changes.amount <= 0 ||
        (changes.amount * 100 - (changes.amount * 100).round()).abs() >
            0.000001) {
      throw Exception(
        'Enter a positive amount with at most two decimal places.',
      );
    }
    await _source.db.runTransaction((transaction) async {
      final roomRef = _source.rooms.doc(roomId);
      final room = (await transaction.get(roomRef)).data();
      final billRef = _ref(roomId).doc(billId);
      final bill = (await transaction.get(billRef)).data();
      if (room == null ||
          bill == null ||
          room['isArchived'] == true ||
          room['isLocked'] == true) {
        throw Exception('This bill cannot be edited.');
      }
      if (!List<String>.from(room['memberIds'] ?? []).contains(performedBy) ||
          (bill['paidBy'] != performedBy && room['adminId'] != performedBy)) {
        throw Exception('Only the active payer or admin can edit this bill.');
      }
      transaction.update(billRef, BillFirestoreMapper.toUpdateMap(changes));
      final nextVersion = (room['ledgerVersion'] as int? ?? 0) + 1;
      transaction.update(roomRef, {'ledgerVersion': nextVersion});
      transaction.set(_source.activities(roomId).doc(), {
        'type': 'billEdited',
        'performedBy': performedBy,
        'description': 'Edited ${changes.type.name} bill',
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'billId': billId,
          'amount': changes.amount,
          'paidBy': bill['paidBy'],
          'splitAmong': bill['splitAmong'] ?? [],
        },
      });
    });
  }

  Future<void> deleteBill(String roomId, String billId) async {
    await _source.writeOpenLedger(roomId, (transaction) async {
      transaction.delete(_ref(roomId).doc(billId));
    });
  }

  Stream<List<BillModel>> getBillsStream(String roomId, String month) {
    return _ref(roomId)
        .where('month', isEqualTo: month)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final list = snap.docs
              .map((d) => BillFirestoreMapper.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }
}
