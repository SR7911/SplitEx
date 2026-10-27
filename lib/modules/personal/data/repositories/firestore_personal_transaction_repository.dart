import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import '../../domain/entities/transactions/personal_transaction.dart';
import '../../domain/entities/transactions/debt_settlement_command.dart';
import '../../domain/entities/transactions/personal_transaction_edit.dart';
import '../../domain/repositories/personal_transaction_repository.dart';
import '../mappers/transactions/personal_transaction_firestore_mapper.dart';

class FirestorePersonalTransactionRepository
    implements PersonalTransactionRepository {
  final FirebaseFirestore _db;
  final UsageTracker _tracker;

  FirestorePersonalTransactionRepository({
    required FirebaseFirestore firestore,
    UsageTracker? tracker,
  }) : _db = firestore,
       _tracker = tracker ?? UsageTracker.instance;

  CollectionReference<Map<String, dynamic>> _transactions(String userId) =>
      _db.collection('users').doc(userId).collection('personal_transactions');

  @override
  Stream<List<PersonalTransaction>> transactionsForMonth(
    String userId,
    String month,
  ) {
    _tracker.trackReads(1);
    return _db
        .collection('users')
        .doc(userId)
        .collection('personal_transactions')
        .where('month', isEqualTo: month)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          _tracker.trackReads(snapshot.docs.length);
          return snapshot.docs
              .map(
                (doc) => PersonalTransactionFirestoreMapper.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList();
        });
  }

  @override
  Stream<List<PersonalTransaction>> debts(String userId) {
    _tracker.trackReads(1);
    return _db
        .collection('users')
        .doc(userId)
        .collection('personal_transactions')
        .where('debtType', whereIn: ['lent', 'borrowed'])
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          _tracker.trackReads(snapshot.docs.length);
          return snapshot.docs
              .map(
                (doc) => PersonalTransactionFirestoreMapper.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList();
        });
  }

  @override
  Future<void> create(String userId, PersonalTransaction transaction) async {
    final accountId = transaction.accountId;
    if (accountId != null) {
      final account = await _db
          .collection('users')
          .doc(userId)
          .collection('personal_accounts')
          .doc(accountId)
          .get();
      if (!account.exists || account.data()?['archived'] == true) {
        throw StateError('Choose an active account.');
      }
    }
    await _db
        .collection('users')
        .doc(userId)
        .collection('personal_transactions')
        .add({
          ...PersonalTransactionFirestoreMapper.toMap(transaction),
          'partialSettlements': const <Map<String, dynamic>>[],
        });
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> update(
    String userId,
    String id,
    PersonalTransactionEdit edit,
  ) => updateRaw(userId, id, {
    'title': edit.title,
    'amount': edit.amount,
    'type': edit.type.name,
    'category': edit.category,
    'date': Timestamp.fromDate(edit.date),
    'notes': edit.notes,
    'month': '${edit.date.year}-${edit.date.month.toString().padLeft(2, '0')}',
    'debtType': edit.debtType?.name,
    'personName': edit.personName,
    'isSettled': edit.isSettled,
    'accountId': edit.accountId,
    'dueDate': edit.dueDate == null ? null : Timestamp.fromDate(edit.dueDate!),
  });

  /// Compatibility boundary for callers that still supply Firestore field maps.
  Future<void> updateRaw(
    String userId,
    String id,
    Map<String, dynamic> data,
  ) async {
    final transactionRef = _transactions(userId).doc(id);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(transactionRef);
      final current = snapshot.data();
      if (current == null) throw StateError('Transaction no longer exists.');
      final updates = Map<String, dynamic>.from(data);
      final assigned = updates['accountId'] as String?;
      if (assigned != null && assigned != current['accountId']) {
        final account = await transaction.get(
          _db
              .collection('users')
              .doc(userId)
              .collection('personal_accounts')
              .doc(assigned),
        );
        if (!account.exists || account.data()?['archived'] == true) {
          throw StateError('Choose an active account.');
        }
      }
      final due =
          (updates.containsKey('dueDate')
                  ? updates['dueDate']
                  : current['dueDate'])
              as Timestamp?;
      final date = ((updates['date'] ?? current['date']) as Timestamp).toDate();
      if (due != null &&
          DateTime(
            due.toDate().year,
            due.toDate().month,
            due.toDate().day,
          ).isBefore(DateTime(date.year, date.month, date.day))) {
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
          final editedDate = (updates['date'] as Timestamp?)?.toDate();
          final history = List<Map<String, dynamic>>.from(
            current['partialSettlements'] ?? [],
          );
          if (editedDate != null &&
              history.any(
                (entry) => DateTime.parse(entry['date'] as String).isBefore(
                  DateTime(editedDate.year, editedDate.month, editedDate.day),
                ),
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

  @override
  Future<void> delete(String userId, String id) async {
    await _transactions(userId).doc(id).delete();
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> settleDebt(
    String userId,
    String id,
    DebtSettlementCommand command,
  ) async {
    final debtRef = _transactions(userId).doc(id);
    final repaymentRef = _transactions(userId).doc();
    final writeOff = command.action == DebtSettlementAction.writeOff;
    final date = writeOff ? DateTime.now() : (command.date ?? DateTime.now());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(debtRef);
      final data = snapshot.data();
      if (data == null || data['isSettled'] == true) return;
      final total = (data['amount'] as num).toDouble();
      final paid = (data['settledAmount'] as num? ?? 0).toDouble();
      final writtenOff = (data['writtenOffAmount'] as num? ?? 0).toDouble();
      final remaining = total - paid - writtenOff;
      final payment = command.action == DebtSettlementAction.partial
          ? command.amount!
          : remaining;
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
            : (command.note ?? 'Settlement'),
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
          'notes': command.note ?? 'Settlement for "${data['title']}"',
          'userId': userId,
          'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
          'createdAt': FieldValue.serverTimestamp(),
          'debtSourceId': id,
          'isSettled': false,
        });
      }
    });
    await _tracker.trackWrites(writeOff ? 1 : 2);
  }
}
