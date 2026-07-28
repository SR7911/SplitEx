import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/services/usage_tracker.dart';

class PersonalExpenseService {
  final _firestore = FirebaseFirestore.instance;
  final _tracker = UsageTracker.instance;

  // ─── Transactions ───

  CollectionReference _txnCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('personal_transactions');

  Stream<List<PersonalTransactionModel>> getTransactionsStream(String userId, String month) {
    _tracker.trackReads(1);
    return _txnCol(userId)
        .where('month', isEqualTo: month)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map((d) => PersonalTransactionModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    });
  }

  Future<void> addTransaction(String userId, PersonalTransactionModel txn) async {
    await _txnCol(userId).add(txn.toMap());
    await _tracker.trackWrites(1);
  }

  Future<void> updateTransaction(String userId, String txnId, Map<String, dynamic> data) async {
    await _txnCol(userId).doc(txnId).update(data);
    await _tracker.trackWrites(1);
  }

  Future<void> deleteTransaction(String userId, String txnId) async {
    await _txnCol(userId).doc(txnId).delete();
    await _tracker.trackWrites(1);
  }

  // ─── Debts ───

  Stream<List<PersonalTransactionModel>> getDebtTransactionsStream(String userId) {
    _tracker.trackReads(1);
    return _txnCol(userId)
        .where('debtType', whereIn: ['lent', 'borrowed'])
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map((d) => PersonalTransactionModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    });
  }

  Future<void> settleTransaction(String userId, String txnId) async {
    final doc = await _txnCol(userId).doc(txnId).get();
    await _tracker.trackReads(1);
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final totalAmount = (data['amount'] ?? 0).toDouble();
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final existing = List<Map<String, dynamic>>.from(data['partialSettlements'] ?? []);
    existing.add({'amount': totalAmount, 'date': now.toIso8601String(), 'note': 'Full settlement'});

    await _txnCol(userId).doc(txnId).update({
      'isSettled': true,
      'settledAmount': totalAmount,
      'partialSettlements': existing,
    });
    await _tracker.trackWrites(1);

    if (data['debtType'] == 'lent') {
      await _txnCol(userId).add({
        'title': 'Settlement: ${data['personName'] ?? 'Unknown'} repaid',
        'amount': totalAmount,
        'type': 'income',
        'category': data['category'] ?? 'Other',
        'date': Timestamp.fromDate(now),
        'notes': 'Auto-generated on settling "${data['title']}"',
        'userId': userId,
        'month': month,
        'createdAt': FieldValue.serverTimestamp(),
        'isSettled': false,
      });
      await _tracker.trackWrites(1);
    }
  }

  Future<void> partialSettleTransaction(String userId, String txnId, double partialAmount, String? note) async {
    final doc = await _txnCol(userId).doc(txnId).get();
    await _tracker.trackReads(1);
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final totalAmount = (data['amount'] ?? 0).toDouble();
    final currentSettled = (data['settledAmount'] ?? 0).toDouble();
    final newSettled = currentSettled + partialAmount;
    final isNowFullySettled = newSettled >= totalAmount;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final existing = List<Map<String, dynamic>>.from(data['partialSettlements'] ?? []);
    existing.add({'amount': partialAmount, 'date': now.toIso8601String(), 'note': note ?? ''});

    await _txnCol(userId).doc(txnId).update({
      'settledAmount': newSettled,
      'isSettled': isNowFullySettled,
      'partialSettlements': existing,
    });
    await _tracker.trackWrites(1);

    if (data['debtType'] == 'lent') {
      await _txnCol(userId).add({
        'title': 'Partial Settlement: ${data['personName'] ?? 'Unknown'} repaid ₹${partialAmount.toStringAsFixed(0)}',
        'amount': partialAmount,
        'type': 'income',
        'category': data['category'] ?? 'Other',
        'date': Timestamp.fromDate(now),
        'notes': note ?? 'Partial settlement for "${data['title']}"',
        'userId': userId,
        'month': month,
        'createdAt': FieldValue.serverTimestamp(),
        'isSettled': false,
      });
      await _tracker.trackWrites(1);
    }
  }

  // ─── Category Budgets ───

  CollectionReference _budgetCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('personal_budgets');

  Stream<List<CategoryBudget>> getBudgetsStream(String userId, String month) {
    _tracker.trackReads(1);
    return _budgetCol(userId)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map((d) => CategoryBudget.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    });
  }

  Future<void> setBudget(String userId, CategoryBudget budget) async {
    final existing = await _budgetCol(userId)
        .where('category', isEqualTo: budget.category)
        .where('month', isEqualTo: budget.month)
        .limit(1)
        .get();
    await _tracker.trackReads(1);

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({'budget': budget.budget});
    } else {
      await _budgetCol(userId).add(budget.toMap());
    }
    await _tracker.trackWrites(1);
  }

  Future<void> deleteBudget(String userId, String budgetId) async {
    await _budgetCol(userId).doc(budgetId).delete();
    await _tracker.trackWrites(1);
  }

  // ─── Recurring Transactions ───

  CollectionReference _recurringCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('personal_recurring');

  Stream<List<RecurringTransaction>> getRecurringStream(String userId) {
    _tracker.trackReads(1);
    return _recurringCol(userId)
        .orderBy('dayOfMonth')
        .snapshots()
        .map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map((d) => RecurringTransaction.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    });
  }

  Future<void> addRecurring(String userId, RecurringTransaction recurring) async {
    await _recurringCol(userId).add(recurring.toMap());
    await _tracker.trackWrites(1);
  }

  Future<void> toggleRecurring(String userId, String id, bool active) async {
    await _recurringCol(userId).doc(id).update({'active': active});
    await _tracker.trackWrites(1);
  }

  Future<void> deleteRecurring(String userId, String id) async {
    await _recurringCol(userId).doc(id).delete();
    await _tracker.trackWrites(1);
  }
}
