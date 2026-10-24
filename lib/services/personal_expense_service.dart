import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/services/usage_tracker.dart';

class PersonalExpenseService {
  final FirebaseFirestore _firestore;
  PersonalExpenseService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final _tracker = UsageTracker.instance;

  // ─── Transactions ───

  CollectionReference _txnCol(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('personal_transactions');

  Stream<List<PersonalTransactionModel>> getTransactionsStream(
    String userId,
    String month,
  ) {
    _tracker.trackReads(1);
    return _txnCol(userId)
        .where('month', isEqualTo: month)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
          _tracker.trackReads(snap.docs.length);
          return snap.docs
              .map(
                (d) => PersonalTransactionModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList();
        });
  }

  Future<void> addTransaction(
    String userId,
    PersonalTransactionModel txn,
  ) async {
    if (!txn.amount.isFinite || txn.amount <= 0) throw StateError('Enter a valid positive amount.');
    if (txn.dueDate != null && DateTime(txn.dueDate!.year, txn.dueDate!.month, txn.dueDate!.day)
        .isBefore(DateTime(txn.date.year, txn.date.month, txn.date.day))) {
      throw StateError('Repayment date cannot be before the debt date.');
    }
    if (txn.accountId != null) {
      final account = await _firestore.collection('users').doc(userId).collection('personal_accounts').doc(txn.accountId).get();
      if (!account.exists || account.data()?['archived'] == true) throw StateError('Choose an active account.');
    }
    await _txnCol(userId).add(txn.toMap());
    await _tracker.trackWrites(1);
  }

  Future<void> updateTransaction(
    String userId,
    String txnId,
    Map<String, dynamic> data,
  ) async {
    final transactionRef = _txnCol(userId).doc(txnId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(transactionRef);
      final current = snapshot.data() as Map<String, dynamic>?;
      if (current == null) throw StateError('Transaction no longer exists.');
      final updates = Map<String, dynamic>.from(data);
      final assigned = updates['accountId'] as String?;
      if (assigned != null && assigned != current['accountId']) {
        final account = await transaction.get(_firestore.collection('users').doc(userId).collection('personal_accounts').doc(assigned));
        if (!account.exists || account.data()?['archived'] == true) throw StateError('Choose an active account.');
      }
      final due = (updates.containsKey('dueDate') ? updates['dueDate'] : current['dueDate']) as Timestamp?;
      final date = ((updates['date'] ?? current['date']) as Timestamp).toDate();
      if (due != null && DateTime(due.toDate().year, due.toDate().month, due.toDate().day).isBefore(DateTime(date.year, date.month, date.day))) {
        throw StateError('Repayment date cannot be before the debt date.');
      }
      if (current['debtType'] != null) {
        final paid = (current['settledAmount'] as num? ?? 0).toDouble();
        final writtenOff = (current['writtenOffAmount'] as num? ?? 0)
            .toDouble();
        final amount = (updates['amount'] as num? ?? current['amount'] as num)
            .toDouble();
        if (!amount.isFinite || amount <= 0 || amount < paid + writtenOff) {
          throw StateError(
            'Amount cannot be less than the settled and written-off balance.',
          );
        }
        if (paid + writtenOff > 0) {
          for (final field in ['debtType', 'personName', 'type']) {
            if (updates.containsKey(field) &&
                updates[field] != current[field]) {
              throw StateError(
                'Cannot change the person or debt direction after settlement.',
              );
            }
          }
          final date = (updates['date'] as Timestamp?)?.toDate();
          final history = List<Map<String, dynamic>>.from(
            current['partialSettlements'] ?? [],
          );
          if (date != null &&
              history.any(
                (entry) => DateTime.parse(
                  entry['date'] as String,
                ).isBefore(DateTime(date.year, date.month, date.day)),
              )) {
            throw StateError(
              'Debt date cannot be after a recorded settlement.',
            );
          }
        }
        updates['isSettled'] = paid + writtenOff >= amount;
      }
      transaction.update(transactionRef, updates);
    });
    await _tracker.trackWrites(1);
  }

  Future<void> deleteTransaction(String userId, String txnId) async {
    await _txnCol(userId).doc(txnId).delete();
    await _tracker.trackWrites(1);
  }

  // ─── Debts ───

  Stream<List<PersonalTransactionModel>> getDebtTransactionsStream(
    String userId,
  ) {
    _tracker.trackReads(1);
    return _txnCol(userId)
        .where('debtType', whereIn: ['lent', 'borrowed'])
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
          _tracker.trackReads(snap.docs.length);
          return snap.docs
              .map(
                (d) => PersonalTransactionModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList();
        });
  }

  Future<void> settleTransaction(
    String userId,
    String txnId, {
    DateTime? settlementDate,
  }) => _recordSettlement(userId, txnId, settlementDate: settlementDate);

  Future<void> partialSettleTransaction(
    String userId,
    String txnId,
    double partialAmount,
    String? note, {
    DateTime? settlementDate,
  }) => _recordSettlement(
    userId,
    txnId,
    amount: partialAmount,
    note: note,
    settlementDate: settlementDate,
  );

  Future<void> closeDebt(String userId, String txnId) =>
      _recordSettlement(userId, txnId, writeOff: true);

  Future<void> _recordSettlement(
    String userId,
    String txnId, {
    double? amount,
    String? note,
    DateTime? settlementDate,
    bool writeOff = false,
  }) async {
    final debtRef = _txnCol(userId).doc(txnId);
    final repaymentRef = _txnCol(userId).doc();
    final date = settlementDate ?? DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(debtRef);
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null || data['isSettled'] == true) return;
      final total = (data['amount'] as num).toDouble();
      final paid = (data['settledAmount'] as num? ?? 0).toDouble();
      final writtenOff = (data['writtenOffAmount'] as num? ?? 0).toDouble();
      final remaining = total - paid - writtenOff;
      final payment = amount ?? remaining;
      if (!payment.isFinite || payment <= 0 || payment > remaining) {
        throw StateError(
          'Amount must be between zero and the remaining balance.',
        );
      }
      final debtDate = (data['date'] as Timestamp).toDate();
      if (DateTime(
        date.year,
        date.month,
        date.day,
      ).isBefore(DateTime(debtDate.year, debtDate.month, debtDate.day))) {
        throw StateError('Settlement date cannot be before the debt date.');
      }
      final history = List<Map<String, dynamic>>.from(
        data['partialSettlements'] ?? [],
      );
      history.add({
        'amount': payment,
        'date': date.toIso8601String(),
        'note': writeOff
            ? 'Closed: unpaid balance written off'
            : (note ?? 'Settlement'),
        'type': writeOff ? 'writeOff' : 'payment',
      });
      transaction.update(debtRef, {
        'settledAmount': writeOff ? paid : paid + payment,
        'isSettled': writeOff || paid + writtenOff + payment >= total,
        'partialSettlements': history,
        if (writeOff) 'writtenOffAmount': writtenOff + remaining,
      });
      if (!writeOff) {
        transaction.set(repaymentRef, {
          'title': 'Settlement: ${data['personName'] ?? 'Unknown'}',
          'amount': payment,
          'type': data['debtType'] == 'lent' ? 'income' : 'expense',
          'category': data['category'] ?? 'Other',
          'date': Timestamp.fromDate(date),
          'notes': note ?? 'Settlement for "${data['title']}"',
          'userId': userId,
          'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
          'createdAt': FieldValue.serverTimestamp(),
          'debtSourceId': txnId,
          'isSettled': false,
        });
      }
    });
    await _tracker.trackWrites(writeOff ? 1 : 2);
  }

  CollectionReference _budgetCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('personal_budgets');

  Stream<List<CategoryBudget>> getBudgetsStream(String userId, String month) {
    _tracker.trackReads(1);
    return _budgetCol(userId).where('month', isEqualTo: month).snapshots().map((
      snap,
    ) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map(
            (d) =>
                CategoryBudget.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
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

  CollectionReference _recurringCol(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('personal_recurring');

  Stream<List<RecurringTransaction>> getRecurringStream(String userId) {
    _tracker.trackReads(1);
    return _recurringCol(userId).orderBy('dayOfMonth').snapshots().map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map(
            (d) => RecurringTransaction.fromMap(
              d.data() as Map<String, dynamic>,
              d.id,
            ),
          )
          .toList();
    });
  }

  Future<void> addRecurring(
    String userId,
    RecurringTransaction recurring,
  ) async {
    await _recurringCol(userId).add({
      ...recurring.toMap(),
      'createdAt': Timestamp.fromDate(recurring.createdAt ?? DateTime.now()),
    });
    await _tracker.trackWrites(1);
  }

  /// Snapshots the current state into editHistory, then applies the new values.
  Future<void> updateRecurring(
    String userId,
    RecurringTransaction current, {
    String? title,
    double? amount,
    String? category,
    RecurringFrequency? frequency,
    int? dayOfMonth,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async {
    // Build snapshot of current state before overwriting
    final snapshot = RecurringEditSnapshot(
      title: current.title,
      amount: current.amount,
      category: current.category,
      frequency: current.frequency,
      dayOfMonth: current.dayOfMonth,
      endDate: current.endDate,
      editedAt: DateTime.now(),
    );

    final updatedHistory = [
      snapshot,
      ...current.editHistory,
    ].map((e) => e.toMap()).toList();

    final updateMap = <String, dynamic>{
      'editHistory': updatedHistory,
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (category != null) 'category': category,
      if (frequency != null) 'frequency': frequency.name,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
    };

    if (clearEndDate) {
      updateMap['endDate'] = FieldValue.delete();
    } else if (endDate != null) {
      updateMap['endDate'] = Timestamp.fromDate(endDate);
    }

    await _recurringCol(userId).doc(current.id).update(updateMap);
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
