import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw Firestore documents and atomic writes for projects and their expenses.
class ProjectFirestoreDataSource {
  final FirebaseFirestore db;
  const ProjectFirestoreDataSource(this.db);

  CollectionReference<Map<String, dynamic>> _projects(String uid) =>
      db.collection('users').doc(uid).collection('projects');
  CollectionReference<Map<String, dynamic>> _expenses(
    String uid,
    String projectId,
  ) => _projects(uid).doc(projectId).collection('expenses');

  Future<(String, Map<String, dynamic>)> createProject(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final doc = _projects(uid).doc();
    await doc.set(data);
    return (doc.id, {...data, 'createdAt': Timestamp.now()});
  }

  Future<void> updateProject(
    String uid,
    String projectId,
    Map<String, dynamic> data,
  ) => _projects(uid).doc(projectId).update(data);

  Future<void> deleteProject(String uid, String projectId) async {
    final expenses = await _expenses(uid, projectId).get();
    final batch = db.batch();
    for (final doc in expenses.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_projects(uid).doc(projectId));
    await batch.commit();
  }

  Stream<List<(String, Map<String, dynamic>)>> watchProjects(String uid) =>
      _projects(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => (doc.id, doc.data())).toList(),
          );

  Stream<Map<String, dynamic>?> watchProject(String uid, String projectId) =>
      _projects(uid).doc(projectId).snapshots().map((doc) => doc.data());

  Future<(String, Map<String, dynamic>)> addExpense(
    String uid,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final doc = _expenses(uid, projectId).doc();
    await doc.set(data);
    return (doc.id, {...data, 'createdAt': Timestamp.now()});
  }

  Future<void> updateExpense(
    String uid,
    String projectId,
    String expenseId,
    Map<String, dynamic> data,
  ) => _expenses(uid, projectId).doc(expenseId).update(data);
  Future<void> deleteExpense(String uid, String projectId, String expenseId) =>
      _expenses(uid, projectId).doc(expenseId).delete();

  Stream<List<(String, Map<String, dynamic>)>> watchExpenses(
    String uid,
    String projectId,
  ) => _expenses(uid, projectId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) => (doc.id, doc.data())).toList(),
      );

  /// The read and write must stay in one transaction to avoid losing payments.
  Future<void> appendPayment(
    String uid,
    String projectId,
    String expenseId, {
    double? partialAmount,
    String? note,
  }) async {
    final ref = _expenses(uid, projectId).doc(expenseId);
    await db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) return;
      final total = (data['amount'] ?? 0).toDouble();
      final paid = (data['settledAmount'] ?? 0).toDouble();
      final amount = partialAmount ?? total;
      final nextPaid = partialAmount == null ? total : paid + amount;
      final history = List<Map<String, dynamic>>.from(
        data['partialSettlements'] ?? [],
      );
      history.add({
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'note': partialAmount == null ? 'Full settlement' : note ?? '',
      });
      transaction.update(ref, {
        'isSettled': nextPaid >= total,
        'settledAmount': nextPaid,
        'partialSettlements': history,
      });
    });
  }
}
