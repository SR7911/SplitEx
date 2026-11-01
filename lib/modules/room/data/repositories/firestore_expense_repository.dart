import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import 'package:split_ex/modules/room/domain/repositories/expense_repository.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';

class FirestoreExpenseRepository implements ExpenseRepository {
  final _tracker = UsageTracker.instance;
  final RoomFirestoreDataSource _source;
  FirestoreExpenseRepository({RoomFirestoreDataSource? source})
    : _source = source ?? RoomFirestoreDataSource();

  CollectionReference<Map<String, dynamic>> _expensesRef(String roomId) {
    return _source.expenses(roomId);
  }

  Future<ExpenseModel> addExpense(String roomId, ExpenseModel expense) async {
    final doc = _expensesRef(roomId).doc();
    await doc.set(ExpenseFirestoreMapper.toMap(expense));
    await _tracker.trackWrites(1);
    return ExpenseFirestoreMapper.fromMap(
      ExpenseFirestoreMapper.toMap(expense)..['createdAt'] = Timestamp.now(),
      doc.id,
    );
  }

  Future<void> updateExpense(
    String roomId,
    String expenseId,
    RoomExpenseUpdate changes,
  ) async {
    await _expensesRef(
      roomId,
    ).doc(expenseId).update(ExpenseFirestoreMapper.toUpdateMap(changes));
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
              .map((doc) => ExpenseFirestoreMapper.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  Stream<List<ExpenseModel>> getAllExpensesStream(String roomId) {
    _tracker.trackReads(1);
    return _expensesRef(
      roomId,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      _tracker.trackReads(snapshot.docs.length);
      return snapshot.docs
          .map((doc) => ExpenseFirestoreMapper.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
