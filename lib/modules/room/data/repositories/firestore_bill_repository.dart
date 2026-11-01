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
    await _ref(roomId).add(BillFirestoreMapper.toMap(bill));
  }

  Future<void> updateBill(
    String roomId,
    String billId,
    RoomBillUpdate changes,
  ) async {
    await _ref(
      roomId,
    ).doc(billId).update(BillFirestoreMapper.toUpdateMap(changes));
  }

  Future<void> deleteBill(String roomId, String billId) async {
    await _ref(roomId).doc(billId).delete();
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
