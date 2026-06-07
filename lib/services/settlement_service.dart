import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/settlement_model.dart';

class SettlementService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String roomId) {
    return _firestore.collection('rooms').doc(roomId).collection('settlements');
  }

  Future<String> createSettlement(String roomId, SettlementModel settlement) async {
    final doc = _ref(roomId).doc();
    await doc.set(settlement.toMap());
    return doc.id;
  }

  Future<void> confirmSettlement(String roomId, String settlementId) async {
    await _ref(roomId).doc(settlementId).update({
      'status': SettlementStatus.confirmed.name,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelSettlement(String roomId, String settlementId) async {
    await _ref(roomId).doc(settlementId).update({
      'status': SettlementStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addUpiRef(String roomId, String settlementId, String upiRef) async {
    await _ref(roomId).doc(settlementId).update({'upiRef': upiRef});
  }

  Stream<List<SettlementModel>> getSettlementsStream(String roomId) {
    return _ref(roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SettlementModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<SettlementModel>> getPendingSettlementsStream(String roomId, String userId) {
    return _ref(roomId)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: SettlementStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SettlementModel.fromMap(d.data(), d.id))
            .toList());
  }
}