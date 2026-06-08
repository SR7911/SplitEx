import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/services/usage_tracker.dart';

class ExpenseService {
  final _tracker = UsageTracker.instance;

  CollectionReference<Map<String, dynamic>> _expensesRef(String roomId) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('expenses');
  }

  Future<ExpenseModel> addExpense(String roomId, ExpenseModel expense) async {
    final doc = _expensesRef(roomId).doc();
    await doc.set(expense.toMap());
    await _tracker.trackWrites(1);
    return ExpenseModel.fromMap(expense.toMap()..['createdAt'] = Timestamp.now(), doc.id);
  }

  Future<void> updateExpense(
      String roomId, String expenseId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _expensesRef(roomId).doc(expenseId).update(data);
    await _tracker.trackWrites(1);
  }

  Future<void> deleteExpense(String roomId, String expenseId) async {
    await _expensesRef(roomId).doc(expenseId).delete();
    await _tracker.trackWrites(1);
  }

  Stream<List<ExpenseModel>> getExpensesStream(String roomId, String month) {
    _tracker.trackReads(1);
    return _expensesRef(roomId)
        .where('month', isEqualTo: month)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      _tracker.trackReads(snapshot.docs.length);
      final list = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<ExpenseModel>> getAllExpensesStream(String roomId) {
    _tracker.trackReads(1);
    return _expensesRef(roomId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      _tracker.trackReads(snapshot.docs.length);
      return snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
