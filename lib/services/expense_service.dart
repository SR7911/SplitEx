import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/expense_model.dart';

class ExpenseService {
  CollectionReference<Map<String, dynamic>> _expensesRef(String roomId) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('expenses');
  }

  Future<ExpenseModel> addExpense(String roomId, ExpenseModel expense) async {
    final doc = _expensesRef(roomId).doc();
    await doc.set(expense.toMap());
    return ExpenseModel.fromMap(expense.toMap()..['createdAt'] = Timestamp.now(), doc.id);
  }

  Future<void> updateExpense(
      String roomId, String expenseId, Map<String, dynamic> data) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return _expensesRef(roomId).doc(expenseId).update(data);
  }

  Future<void> deleteExpense(String roomId, String expenseId) {
    return _expensesRef(roomId).doc(expenseId).delete();
  }

  Stream<List<ExpenseModel>> getExpensesStream(String roomId, String month) {
    return _expensesRef(roomId)
        .where('month', isEqualTo: month)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Stream<List<ExpenseModel>> getAllExpensesStream(String roomId) {
    return _expensesRef(roomId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
