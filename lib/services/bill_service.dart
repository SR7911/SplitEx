import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/bill_model.dart';

class BillService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String roomId) {
    return _firestore.collection('rooms').doc(roomId).collection('bills');
  }

  Future<void> addBill(String roomId, BillModel bill) async {
    await _ref(roomId).add(bill.toMap());
  }

  Future<void> updateBill(String roomId, String billId, Map<String, dynamic> data) async {
    await _ref(roomId).doc(billId).update(data);
  }

  Future<void> deleteBill(String roomId, String billId) async {
    await _ref(roomId).doc(billId).delete();
  }

  Stream<List<BillModel>> getBillsStream(String roomId, String month) {
    return _ref(roomId)
        .where('month', isEqualTo: month)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final list = snap.docs.map((d) => BillModel.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
}
