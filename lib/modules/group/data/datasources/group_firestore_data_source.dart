import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore paths and raw document operations for the Group module.
class GroupFirestoreDataSource {
  final FirebaseFirestore db;
  const GroupFirestoreDataSource(this.db);

  CollectionReference<Map<String, dynamic>> get _groups =>
      db.collection('groups');
  CollectionReference<Map<String, dynamic>> _expenses(String groupId) =>
      _groups.doc(groupId).collection('expenses');
  CollectionReference<Map<String, dynamic>> _settlements(String groupId) =>
      _groups.doc(groupId).collection('settlements');

  Future<(String, Map<String, dynamic>)> createGroup(
    Map<String, dynamic> data,
  ) async {
    final doc = _groups.doc();
    await doc.set(data);
    return (doc.id, {...data, 'createdAt': Timestamp.now()});
  }

  Future<(String, Map<String, dynamic>)?> findByInviteCode(String code) async {
    final result = await _groups
        .where('inviteCode', isEqualTo: code)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    final doc = result.docs.first;
    return (doc.id, doc.data());
  }

  Future<Map<String, dynamic>> addMember(String groupId, String userId) {
    final ref = _groups.doc(groupId);
    return db.runTransaction((transaction) async {
      final latest = await transaction.get(ref);
      final data = latest.data();
      if (data == null) throw Exception('Group not found.');
      if (data['status'] == 'archived')
        throw Exception('This group is archived.');
      final members = List<String>.from(data['memberIds'] ?? []);
      if (members.contains(userId)) throw Exception('Already a member.');
      transaction.update(ref, {
        'memberIds': FieldValue.arrayUnion([userId]),
      });
      return {
        ...data,
        'memberIds': [...members, userId],
      };
    });
  }

  Future<void> leaveGroup(String groupId, String userId) =>
      _groups.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
  Future<void> setGroupStatus(String groupId, String status) =>
      _groups.doc(groupId).update({'status': status});

  Stream<List<(String, Map<String, dynamic>)>> watchUserGroups(String userId) =>
      _groups
          .where('memberIds', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => (doc.id, doc.data())).toList(),
          );

  Stream<Map<String, dynamic>?> watchGroup(String groupId) =>
      _groups.doc(groupId).snapshots().map((doc) => doc.data());

  Future<(String, Map<String, dynamic>)> addExpense(
    String groupId,
    Map<String, dynamic> data,
  ) async {
    final doc = _expenses(groupId).doc();
    await doc.set(data);
    return (doc.id, {...data, 'createdAt': Timestamp.now()});
  }

  Future<void> updateExpense(
    String groupId,
    String expenseId,
    Map<String, dynamic> data,
  ) => _expenses(groupId).doc(expenseId).update(data);
  Future<void> deleteExpense(String groupId, String expenseId) =>
      _expenses(groupId).doc(expenseId).delete();
  Stream<List<(String, Map<String, dynamic>)>> watchExpenses(String groupId) =>
      _expenses(groupId).snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => (doc.id, doc.data())).toList(),
      );

  Future<void> createSettlement(
    String groupId,
    Map<String, dynamic> data,
  ) async {
    final doc = _settlements(groupId).doc();
    await doc.set(data);
  }

  Future<void> updateSettlement(
    String groupId,
    String id,
    Map<String, dynamic> data,
  ) => _settlements(groupId).doc(id).update(data);
  Stream<List<(String, Map<String, dynamic>)>> watchSettlements(
    String groupId,
  ) => _settlements(groupId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) => (doc.id, doc.data())).toList(),
      );
}
