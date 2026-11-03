import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import '../../domain/entities/transactions/personal_transaction.dart';
import '../../domain/entities/transactions/expense_split.dart';
import '../../domain/policies/debts/debt_tally.dart';
import '../../domain/entities/transactions/debt_settlement_command.dart';
import '../../domain/entities/transactions/personal_transaction_edit.dart';
import '../../domain/repositories/personal_transaction_repository.dart';
import '../models/personal_transaction_firestore_model.dart';
import '../datasources/personal_firestore_data_source.dart';

class FirestorePersonalTransactionRepository
    implements PersonalTransactionRepository {
  final FirebaseFirestore _db;
  late final PersonalFirestoreDataSource _source = PersonalFirestoreDataSource(
    _db,
  );
  final UsageTracker _tracker;

  FirestorePersonalTransactionRepository({
    required FirebaseFirestore firestore,
    UsageTracker? tracker,
  }) : _db = firestore,
       _tracker = tracker ?? UsageTracker.instance;

  CollectionReference<Map<String, dynamic>> _transactions(String userId) =>
      _source.transactions(userId);

  @override
  Stream<List<PersonalTransaction>> transactionsForMonth(
    String userId,
    String month,
  ) {
    _tracker.trackReads(1);
    return _source
        .transactions(userId)
        .where('month', isEqualTo: month)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          _tracker.trackReads(snapshot.docs.length);
          return snapshot.docs
              .where((doc) => doc.data()['splitSourceId'] == null)
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
    return _source
        .transactions(userId)
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
      final account = await _source.accounts(userId).doc(accountId).get();
      if (!account.exists || account.data()?['archived'] == true) {
        throw StateError('Choose an active account.');
      }
    }
    final collection = _transactions(userId);
    final parentRef = collection.doc();
    final split = transaction.split;
    if (split == null) {
      await parentRef.set({
        ...PersonalTransactionFirestoreMapper.toMap(transaction),
        'partialSettlements': const <Map<String, dynamic>>[],
      });
      await _tracker.trackWrites(1);
      return;
    }
    split.validate(transaction.amount);
    if (transaction.type != TransactionType.expense || transaction.hasDebt) {
      throw StateError('Only a regular expense can be split.');
    }
    final batch = _db.batch();
    final shares = <Map<String, dynamic>>[];
    for (final share in split.shares) {
      final childRef = collection.doc();
      shares.add({
        'personName': share.personName.trim(),
        'amount': share.amount,
        'debtId': childRef.id,
      });
      batch.set(
        childRef,
        _splitDebtData(
          userId: userId,
          parentId: parentRef.id,
          title: transaction.title,
          category: transaction.category,
          date: transaction.date,
          personName: share.personName.trim(),
          amount: share.amount,
          dueDate: transaction.dueDate,
        ),
      );
    }
    batch.set(parentRef, {
      ...PersonalTransactionFirestoreMapper.toMap(transaction),
      'splitShares': shares,
      'partialSettlements': const <Map<String, dynamic>>[],
    });
    await batch.commit();
    await _tracker.trackWrites(shares.length + 1);
  }

  @override
  Future<void> update(String userId, String id, PersonalTransactionEdit edit) =>
      updateRaw(
        userId,
        id,
        {
          'title': edit.title,
          'amount': edit.amount,
          'type': edit.type.name,
          'category': edit.category,
          'date': Timestamp.fromDate(edit.date),
          'notes': edit.notes,
          'month':
              '${edit.date.year}-${edit.date.month.toString().padLeft(2, '0')}',
          'debtType': edit.debtType?.name,
          'personName': edit.personName,
          'isSettled': edit.isSettled,
          'accountId': edit.accountId,
          'dueDate': edit.dueDate == null
              ? null
              : Timestamp.fromDate(edit.dueDate!),
        },
        editSplit: true,
        split: edit.split,
      );

  /// Compatibility boundary for callers that still supply Firestore field maps.
  Future<void> updateRaw(
    String userId,
    String id,
    Map<String, dynamic> data, {
    bool editSplit = false,
    ExpenseSplit? split,
  }) async {
    final transactionRef = _transactions(userId).doc(id);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(transactionRef);
      final current = snapshot.data();
      if (current == null) throw StateError('Transaction no longer exists.');
      if (current['splitSourceId'] != null) {
        throw StateError(
          'Edit the original expense to change this split share.',
        );
      }
      if (current['debtSourceId'] != null) {
        throw StateError(
          'This payment belongs to a debt. View its history in Debts.',
        );
      }
      final updates = Map<String, dynamic>.from(data);
      final assigned = updates['accountId'] as String?;
      if (assigned != null && assigned != current['accountId']) {
        final account = await transaction.get(
          _source.accounts(userId).doc(assigned),
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
      final oldShares = List<Map<String, dynamic>>.from(
        current['splitShares'] ?? const <Map<String, dynamic>>[],
      );
      if (oldShares.isNotEmpty || split != null) {
        if (!editSplit) {
          throw StateError('Edit the original expense to change its split.');
        }
        if (updates['type'] != 'expense' || updates['debtType'] != null) {
          throw StateError('A split expense must remain a regular expense.');
        }
        final total = (updates['amount'] as num).toDouble();
        split?.validate(total);
        final oldRefs = <String, DocumentReference<Map<String, dynamic>>>{};
        final oldData = <String, Map<String, dynamic>>{};
        for (final old in oldShares) {
          final debtId = old['debtId'] as String?;
          if (debtId == null) throw StateError('Split data is incomplete.');
          final ref = _transactions(userId).doc(debtId);
          oldRefs[debtPersonKey(old['personName'] as String)] = ref;
          final child = await transaction.get(ref);
          if (!child.exists || child.data()?['splitSourceId'] != id) {
            throw StateError('A split debt is missing. Refresh and try again.');
          }
          oldData[ref.id] = child.data()!;
        }
        final newShares = <Map<String, dynamic>>[];
        final retainedIds = <String>{};
        for (final share in split?.shares ?? const <ExpenseSplitShare>[]) {
          final name = share.personName.trim();
          final ref =
              oldRefs[debtPersonKey(name)] ?? _transactions(userId).doc();
          final previous = oldData[ref.id];
          final settled = (previous?['settledAmount'] as num? ?? 0).toDouble();
          final writtenOff = (previous?['writtenOffAmount'] as num? ?? 0)
              .toDouble();
          if (moneyCents(share.amount) < moneyCents(settled + writtenOff)) {
            throw StateError(
              '$name’s share is below its recorded settlements.',
            );
          }
          _validateSplitHistoryDate(previous, date);
          retainedIds.add(ref.id);
          newShares.add({
            'personName': name,
            'amount': share.amount,
            'debtId': ref.id,
          });
        }
        for (final old in oldShares) {
          final oldRef = _transactions(userId).doc(old['debtId'] as String);
          if (retainedIds.contains(oldRef.id)) continue;
          if (_hasSplitSettlement(oldData[oldRef.id]!)) {
            throw StateError(
              'Cannot remove a share with recorded settlements.',
            );
          }
        }
        // All reads finish before the first transaction write.
        for (final old in oldShares) {
          final oldRef = _transactions(userId).doc(old['debtId'] as String);
          if (!retainedIds.contains(oldRef.id)) transaction.delete(oldRef);
        }
        for (final share in newShares) {
          final ref = _transactions(userId).doc(share['debtId'] as String);
          final previous = oldData[ref.id];
          final debtData = _splitDebtData(
            userId: userId,
            parentId: id,
            title: updates['title'] as String,
            category: updates['category'] as String,
            date: date,
            personName: share['personName'] as String,
            amount: (share['amount'] as num).toDouble(),
            dueDate: due?.toDate(),
          );
          if (previous == null) {
            transaction.set(ref, debtData);
          } else {
            transaction.update(ref, {
              'title': debtData['title'],
              'category': debtData['category'],
              'date': debtData['date'],
              'month': debtData['month'],
              'personName': debtData['personName'],
              'amount': debtData['amount'],
              'dueDate': debtData['dueDate'],
              'isSettled':
                  moneyCents((share['amount'] as num).toDouble()) ==
                  moneyCents(
                    (previous['settledAmount'] as num? ?? 0).toDouble() +
                        (previous['writtenOffAmount'] as num? ?? 0).toDouble(),
                  ),
            });
          }
        }
        updates['splitShares'] = newShares;
        updates['splitMode'] = split?.mode.name;
      }
      transaction.update(transactionRef, updates);
    });
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> delete(String userId, String id) async {
    final ref = _transactions(userId).doc(id);
    var writes = 1;
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) return;
      if (data['splitSourceId'] != null) {
        throw StateError(
          'Delete the original expense to remove this split share.',
        );
      }
      if (data['debtSourceId'] != null) {
        throw StateError(
          'This payment belongs to a debt. View its history in Debts.',
        );
      }
      if ((data['partialSettlements'] as List?)?.isNotEmpty == true) {
        throw StateError('A debt with settlement history cannot be deleted.');
      }
      final shares = List<Map<String, dynamic>>.from(
        data['splitShares'] ?? const <Map<String, dynamic>>[],
      );
      final children = <DocumentReference<Map<String, dynamic>>>[];
      for (final share in shares) {
        final debtId = share['debtId'] as String?;
        if (debtId == null) throw StateError('Split data is incomplete.');
        final child = _transactions(userId).doc(debtId);
        final childSnapshot = await transaction.get(child);
        if (childSnapshot.data()?['splitSourceId'] != id) {
          throw StateError('A split debt is missing. Refresh and try again.');
        }
        if (_hasSplitSettlement(childSnapshot.data()!)) {
          throw StateError(
            'Cannot delete an expense with settled split shares.',
          );
        }
        children.add(child);
      }
      for (final child in children) transaction.delete(child);
      transaction.delete(ref);
      writes = children.length + 1;
    });
    await _tracker.trackWrites(writes);
  }

  Map<String, dynamic> _splitDebtData({
    required String userId,
    required String parentId,
    required String title,
    required String category,
    required DateTime date,
    required String personName,
    required double amount,
    required DateTime? dueDate,
  }) => {
    'title': 'Share of $title',
    'amount': amount,
    'type': 'expense',
    'category': category,
    'date': Timestamp.fromDate(date),
    'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
    'createdAt': FieldValue.serverTimestamp(),
    'userId': userId,
    'debtType': 'lent',
    'personName': personName,
    'splitSourceId': parentId,
    'isSettled': false,
    'settledAmount': 0,
    'writtenOffAmount': 0,
    'partialSettlements': const <Map<String, dynamic>>[],
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
  };

  bool _hasSplitSettlement(Map<String, dynamic> data) =>
      (data['settledAmount'] as num? ?? 0) != 0 ||
      (data['writtenOffAmount'] as num? ?? 0) != 0 ||
      (data['partialSettlements'] as List?)?.isNotEmpty == true;

  void _validateSplitHistoryDate(Map<String, dynamic>? data, DateTime date) {
    if (data == null) return;
    final start = DateTime(date.year, date.month, date.day);
    for (final item in (data['partialSettlements'] as List? ?? const [])) {
      final historyDate = DateTime.tryParse(
        (item as Map)['date']?.toString() ?? '',
      );
      if (historyDate != null && historyDate.isBefore(start)) {
        throw StateError('Expense date cannot be after a split settlement.');
      }
    }
  }

  @override
  Future<void> settleDebt(
    String userId,
    String id,
    DebtSettlementCommand command,
  ) async {
    final debtRef = _transactions(userId).doc(id);
    final writeOff = command.action == DebtSettlementAction.writeOff;
    final date = writeOff ? DateTime.now() : (command.date ?? DateTime.now());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(debtRef);
      final data = snapshot.data();
      if (data == null || data['isSettled'] == true) return;
      if (data['debtType'] != 'lent' && data['debtType'] != 'borrowed') {
        throw StateError('Select an existing personal debt.');
      }
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
      final accountId = command.accountId;
      if (!writeOff && accountId != null) {
        final account = await transaction.get(
          _source.accounts(userId).doc(accountId),
        );
        if (!account.exists || account.data()?['archived'] == true) {
          throw StateError('Choose an active account for this payment.');
        }
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
        if (!writeOff) 'cashEntry': true,
        if (!writeOff && accountId != null) 'accountId': accountId,
      });
      transaction.update(debtRef, {
        'settledAmount': writeOff ? paid : paid + payment,
        'isSettled': writeOff || paid + writtenOff + payment >= total,
        'partialSettlements': history,
        if (writeOff) 'writtenOffAmount': writtenOff + remaining,
      });
    });
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> tallyDebts(
    String userId,
    String personName, {
    int? expectedOffsetCents,
    int? expectedNetCents,
  }) async {
    final key = debtPersonKey(personName);
    if (key.isEmpty) throw StateError('Choose a person to tally with.');
    final snapshot = await _transactions(
      userId,
    ).where('debtType', whereIn: ['lent', 'borrowed']).get();
    _tracker.trackReads(snapshot.docs.length + 1);
    final ids = snapshot.docs
        .where(
          (doc) =>
              debtPersonKey(doc.data()['personName']?.toString() ?? '') == key &&
              isActiveTallyDebt(PersonalTransactionFirestoreMapper.fromMap(doc.data(), doc.id)),
        )
        .map((doc) => doc.id)
        .toList();
    if (ids.length > 200) {
      throw StateError(
        'Too many debts for one tally. Settle some separately first.',
      );
    }
    if (ids.isEmpty) throw StateError('No debts found for this person.');
    var writes = 0;
    await _db.runTransaction((transaction) async {
      final debts = <PersonalTransaction>[];
      final refs = <String, DocumentReference<Map<String, dynamic>>>{};
      final raw = <String, Map<String, dynamic>>{};
      for (final id in ids) {
        final ref = _transactions(userId).doc(id);
        final data = (await transaction.get(ref)).data();
        if (data == null ||
            debtPersonKey(data['personName']?.toString() ?? '') != key) {
          throw StateError('Debts changed. Refresh the tally preview.');
        }
        refs[id] = ref;
        raw[id] = data;
        debts.add(PersonalTransactionFirestoreMapper.fromMap(data, id));
      }
      final plan = planDebtTally(personName, debts);
      if (!plan.canTally)
        throw StateError('No opposing balances remain to tally.');
      if ((expectedOffsetCents != null &&
              plan.offsetCents != expectedOffsetCents) ||
          (expectedNetCents != null && plan.netCents != expectedNetCents)) {
        throw StateError(
          'Debts changed. Review the updated tally and try again.',
        );
      }
      final now = DateTime.now();
      final tallyId = _transactions(userId).doc().id;
      for (final entry in plan.offsetsCents.entries) {
        final data = raw[entry.key]!;
        final amount = entry.value / 100;
        final paid = (data['settledAmount'] as num? ?? 0).toDouble();
        final writtenOff = (data['writtenOffAmount'] as num? ?? 0).toDouble();
        final total = (data['amount'] as num).toDouble();
        final history = List<Map<String, dynamic>>.from(
          data['partialSettlements'] ?? const <Map<String, dynamic>>[],
        );
        history.add({
          'amount': amount,
          'date': now.toIso8601String(),
          'note': 'Offset against an opposing debt with $personName',
          'type': 'tally',
          'tallyId': tallyId,
        });
        transaction.update(refs[entry.key]!, {
          'settledAmount': paid + amount,
          'isSettled':
              roundedMoneyCents(paid + writtenOff + amount) >= roundedMoneyCents(total),
          'partialSettlements': history,
        });
      }
      writes = plan.offsetsCents.length;
    });
    await _tracker.trackWrites(writes);
  }
}
