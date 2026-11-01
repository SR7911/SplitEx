import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_debt_allocation.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_merchant_category_repository.dart';
import 'package:split_ex/modules/personal/data/models/merchant_category_rule_firestore_model.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart';
import 'package:split_ex/modules/personal/data/datasources/personal_firestore_data_source.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/data/models/personal_transaction_firestore_model.dart';

export 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart'
    show BankSmsMatch, BankSmsSaveResult, BankSmsDebtAllocation;

class FirestoreBankSmsRepository implements PersonalBankSmsRepository {
  final FirebaseFirestore _db;
  late final PersonalFirestoreDataSource _source = PersonalFirestoreDataSource(
    _db,
  );
  FirestoreBankSmsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _source.transactions(uid);
  DocumentReference<Map<String, dynamic>> _receipt(
    String uid,
    ParsedBankSms sms,
  ) => _source.smsReceipts(uid).doc(sms.transactionId);

  Future<bool> wasRecorded(String uid, ParsedBankSms sms) async =>
      (await _receipt(uid, sms).get()).exists;
  Future<String?> suggestedCategory(String uid, ParsedBankSms sms) =>
      FirestoreMerchantCategoryRepository(firestore: _db).suggestion(uid, sms);

  Future<List<BankSmsMatch>> possibleMatches(
    String uid,
    ParsedBankSms sms,
  ) async {
    // Date-only filtering avoids a composite index and covers late bank alerts.
    final min = DateTime(sms.date.year, sms.date.month, sms.date.day - 1);
    final max = DateTime(sms.date.year, sms.date.month, sms.date.day + 2);
    final docs = await _transactions(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(min))
        .where('date', isLessThan: Timestamp.fromDate(max))
        .get();
    final type = sms.direction == BankSmsDirection.debit ? 'expense' : 'income';
    final matches = docs.docs
        .where((doc) {
          final data = doc.data();
          return data['type'] == type &&
              ((data['amount'] as num? ?? 0).toDouble() * 100).round() ==
                  sms.amountMinor;
        })
        .map(
          (doc) => BankSmsMatch(
            id: doc.id,
            title: doc.data()['title'] as String? ?? 'Transaction',
            amount: (doc.data()['amount'] as num).toDouble(),
            date: (doc.data()['date'] as Timestamp).toDate(),
          ),
        )
        .toList();
    final transfers = await _source
        .transfers(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(min))
        .where('date', isLessThan: Timestamp.fromDate(max))
        .get();
    matches.addAll(
      transfers.docs
          .where(
            (d) =>
                ((d.data()['amount'] as num) * 100).round() == sms.amountMinor,
          )
          .map(
            (d) => BankSmsMatch(
              id: d.id,
              title: d.data()['note'] as String? ?? 'Own-account transfer',
              amount: (d.data()['amount'] as num).toDouble(),
              date: (d.data()['date'] as Timestamp).toDate(),
              isTransfer: true,
            ),
          ),
    );
    return matches;
  }

  @override
  Future<List<PersonalTransaction>> openDebtsForSms(
    String uid,
    ParsedBankSms sms,
  ) async {
    final type = sms.direction == BankSmsDirection.credit ? 'lent' : 'borrowed';
    final snapshot = await _transactions(
      uid,
    ).where('debtType', isEqualTo: type).get();
    return snapshot.docs
        .map(
          (doc) =>
              PersonalTransactionFirestoreMapper.fromMap(doc.data(), doc.id),
        )
        .where(
          (debt) =>
              !debt.isSettled &&
              debt.remainingAmount > 0 &&
              normalizedDebtPerson(debt.personName).isNotEmpty,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<BankSmsSaveResult> saveDebtSettlement(
    String uid,
    ParsedBankSms sms, {
    required List<BankSmsDebtAllocation> allocations,
    String? accountId,
    DateTime? date,
  }) async {
    if (allocations.isEmpty ||
        allocations.any((item) => item.amountMinor <= 0) ||
        allocations.map((item) => item.debtId).toSet().length !=
            allocations.length ||
        allocations.fold<int>(0, (total, item) => total + item.amountMinor) !=
            sms.amountMinor) {
      throw StateError('Allocate the full SMS amount to distinct debts.');
    }
    final receipt = _receipt(uid, sms);
    final when = date ?? sms.date;
    return _db.runTransaction((tx) async {
      if ((await tx.get(receipt)).exists) return BankSmsSaveResult.duplicate;
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final item in allocations) {
        snapshots.add(await tx.get(_transactions(uid).doc(item.debtId)));
      }
      if (accountId != null) {
        final account = await tx.get(_source.accounts(uid).doc(accountId));
        if (!account.exists || account.data()?['archived'] == true) {
          throw StateError('Choose an active account for this payment.');
        }
      }
      String? person;
      final updates = <Map<String, dynamic>>[];
      for (var i = 0; i < allocations.length; i++) {
        final debt = snapshots[i].data();
        final item = allocations[i];
        if (debt == null || debt['isSettled'] == true) {
          throw StateError('A selected debt is no longer available.');
        }
        final directionMatches =
            (debt['debtType'] == 'lent' &&
                sms.direction == BankSmsDirection.credit) ||
            (debt['debtType'] == 'borrowed' &&
                sms.direction == BankSmsDirection.debit);
        if (!directionMatches) {
          throw StateError('The SMS direction does not match a selected debt.');
        }
        final currentPerson = normalizedDebtPerson(
          debt['personName'] as String?,
        );
        if (currentPerson.isEmpty ||
            (person != null && currentPerson != person)) {
          throw StateError('Choose debts for the same person.');
        }
        person = currentPerson;
        final totalCents = ((debt['amount'] as num) * 100).round();
        final paidCents = ((debt['settledAmount'] as num? ?? 0) * 100).round();
        final writtenOffCents = ((debt['writtenOffAmount'] as num? ?? 0) * 100)
            .round();
        if (item.amountMinor > totalCents - paidCents - writtenOffCents) {
          throw StateError('A selected debt has changed. Review its balance.');
        }
        final debtDate = (debt['date'] as Timestamp).toDate();
        if (DateTime(
          when.year,
          when.month,
          when.day,
        ).isBefore(DateTime(debtDate.year, debtDate.month, debtDate.day))) {
          throw StateError('Payment date cannot be before a debt date.');
        }
        final history = List<Map<String, dynamic>>.from(
          debt['partialSettlements'] ?? const <Map<String, dynamic>>[],
        );
        history.add({
          'amount': item.amountMinor / 100,
          'date': when.toIso8601String(),
          'note':
              'Bank SMS from ${sms.sender}'
              '${sms.reference == null ? '' : ' · Ref ${sms.reference}'}',
          'type': 'payment',
          'cashEntry': true,
          'bankSmsReceiptId': sms.transactionId,
          if (accountId != null) 'accountId': accountId,
        });
        updates.add({
          'settledAmount': (paidCents + item.amountMinor) / 100,
          'isSettled':
              paidCents + writtenOffCents + item.amountMinor >= totalCents,
          'partialSettlements': history,
        });
      }
      for (var i = 0; i < allocations.length; i++) {
        tx.update(snapshots[i].reference, updates[i]);
      }
      tx.set(receipt, {
        if (allocations.length == 1) 'debtId': allocations.single.debtId,
        'debtIds': allocations.map((item) => item.debtId).toList(),
        'allocations': allocations
            .map(
              (item) => {
                'debtId': item.debtId,
                'amountMinor': item.amountMinor,
              },
            )
            .toList(),
        'messageId': sms.messageId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return BankSmsSaveResult.recorded;
    });
  }

  Future<BankSmsSaveResult> saveTransfer(
    String uid,
    ParsedBankSms sms, {
    String? existingId,
    String? fromAccountId,
    String? toAccountId,
    double? amount,
    DateTime? date,
    String? note,
  }) async {
    final value = amount ?? sms.amount;
    if (!value.isFinite || value <= 0 || (value * 100).round() == 0) {
      throw StateError('Enter a valid transfer amount.');
    }
    if (existingId == null &&
        (fromAccountId == null ||
            toAccountId == null ||
            fromAccountId == toAccountId)) {
      throw StateError('Choose two different accounts.');
    }
    final receipt = _receipt(uid, sms);
    final user = _source.user(uid);
    final target = user
        .collection('personal_transfers')
        .doc(existingId ?? sms.transactionId);
    return _db.runTransaction((tx) async {
      if ((await tx.get(receipt)).exists) return BankSmsSaveResult.duplicate;
      final existing = await tx.get(target);
      if (existingId != null) {
        if (!existing.exists ||
            ((existing.data()!['amount'] as num) * 100).round() !=
                sms.amountMinor) {
          throw StateError('The selected transfer no longer matches.');
        }
      } else if (!existing.exists) {
        final from = await tx.get(
          user.collection('personal_accounts').doc(fromAccountId),
        );
        final to = await tx.get(
          user.collection('personal_accounts').doc(toAccountId),
        );
        if (!from.exists ||
            !to.exists ||
            from.data()?['archived'] == true ||
            to.data()?['archived'] == true) {
          throw StateError('Choose active accounts.');
        }
        tx.set(target, {
          'fromAccountId': fromAccountId,
          'toAccountId': toAccountId,
          'amount': (value * 100).round() / 100,
          'date': Timestamp.fromDate(date ?? sms.date),
          'note': note ?? sms.title,
          'source': 'bank_sms',
          'bankReference': sms.reference,
        });
      }
      tx.set(receipt, {
        'transferId': target.id,
        'messageId': sms.messageId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return existing.exists && existingId == null
          ? BankSmsSaveResult.duplicate
          : BankSmsSaveResult.recorded;
    });
  }

  Future<BankSmsSaveResult> save(
    String uid,
    ParsedBankSms sms, {
    String? existingId,
    String? title,
    double? amount,
    String category = 'Other',
    DateTime? date,
    BankSmsDirection? direction,
    String? accountId,
    bool matchAccount = false,
    bool applyMerchantRule = false,
    bool rememberCategory = false,
  }) async {
    final value = amount ?? sms.amount;
    if (!value.isFinite || value <= 0) {
      throw StateError('Enter a valid positive amount.');
    }
    final type = (direction ?? sms.direction) == BankSmsDirection.debit
        ? 'expense'
        : 'income';
    final when = date ?? sms.date;
    final receipt = _receipt(uid, sms);
    final target = _transactions(uid).doc(existingId ?? sms.transactionId);
    var assignedAccount = accountId;
    if (assignedAccount == null && matchAccount && sms.accountLast4 != null) {
      final matches = await _source
          .accounts(uid)
          .where('last4', isEqualTo: sms.accountLast4)
          .get();
      final active = matches.docs
          .where(
            (d) => d.data()['archived'] != true && d.data()['type'] != 'cash',
          )
          .toList();
      if (active.length == 1) assignedAccount = active.single.id;
    }
    return _db.runTransaction((transaction) async {
      final processed = await transaction.get(receipt);
      if (processed.exists) return BankSmsSaveResult.duplicate;
      final existing = await transaction.get(target);
      final rule = FirestoreMerchantCategoryRepository(
        firestore: _db,
      ).ruleFor(uid, sms);
      var selectedCategory = category;
      if (applyMerchantRule && existingId == null && rule != null) {
        final savedRule = (await transaction.get(rule)).data();
        if (savedRule != null && savedRule['enabled'] != false)
          selectedCategory = savedRule['category'] as String? ?? category;
      }
      if (existingId == null && assignedAccount != null) {
        final account = await transaction.get(
          _source.accounts(uid).doc(assignedAccount),
        );
        if (!account.exists || account.data()?['archived'] == true) {
          throw StateError('Choose an active account.');
        }
      }
      if (existingId != null && !existing.exists) {
        throw StateError('The selected transaction no longer exists.');
      }
      final metadata = {
        'bankReference': sms.reference,
        'bankAccountLast4': sms.accountLast4,
        'bankSmsSender': sms.sender,
        'bankSmsMessageId': sms.messageId,
      };
      if (existingId != null) {
        final data = existing.data()!;
        if (data['type'] != type ||
            ((data['amount'] as num).toDouble() * 100).round() !=
                sms.amountMinor) {
          throw StateError(
            'The selected transaction no longer matches this message.',
          );
        }
        transaction.update(target, metadata);
      } else if (!existing.exists) {
        transaction.set(target, {
          'title': title?.trim().isNotEmpty == true ? title!.trim() : sms.title,
          'amount': value,
          'type': type,
          'category': selectedCategory,
          'date': Timestamp.fromDate(when),
          'month': DateFormat('yyyy-MM').format(when),
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'notes':
              'Recorded from bank SMS (${sms.sender})'
              '${sms.reference == null ? '' : ' · Ref ${sms.reference}'}'
              '${sms.accountLast4 == null ? '' : ' · Account ending ${sms.accountLast4}'}',
          'source': 'bank_sms',
          'accountId': ?assignedAccount,
          'isSettled': false,
          'settledAmount': 0,
          'partialSettlements': [],
          ...metadata,
        });
      }
      transaction.set(receipt, {
        'transactionId': target.id,
        'messageId': sms.messageId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (rememberCategory &&
          existingId == null &&
          !existing.exists &&
          type == 'expense' &&
          rule != null) {
        transaction.set(
          rule,
          MerchantCategoryRule(
            sender: sms.sender,
            merchant: sms.merchant!,
            category: category,
          ).toMap(),
        );
      }
      return existing.exists && existingId == null
          ? BankSmsSaveResult.duplicate
          : BankSmsSaveResult.recorded;
    });
  }
}
