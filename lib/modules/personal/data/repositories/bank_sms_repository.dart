import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/data/repositories/merchant_category_service.dart';
import 'package:split_ex/modules/personal/data/mappers/sms/merchant_category_rule_mapper.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart';

export 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart'
    show BankSmsMatch, BankSmsSaveResult;

class BankSmsRepository implements PersonalBankSmsRepository {
  final FirebaseFirestore _db;
  BankSmsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _db.collection('users').doc(uid).collection('personal_transactions');
  DocumentReference<Map<String, dynamic>> _receipt(
    String uid,
    ParsedBankSms sms,
  ) => _db
      .collection('users')
      .doc(uid)
      .collection('bank_sms_receipts')
      .doc(sms.transactionId);

  Future<bool> wasRecorded(String uid, ParsedBankSms sms) async =>
      (await _receipt(uid, sms).get()).exists;
  Future<String?> suggestedCategory(String uid, ParsedBankSms sms) =>
      MerchantCategoryService(firestore: _db).suggestion(uid, sms);

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
    final transfers = await _db
        .collection('users')
        .doc(uid)
        .collection('personal_transfers')
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
    final user = _db.collection('users').doc(uid);
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
      final matches = await _db
          .collection('users')
          .doc(uid)
          .collection('personal_accounts')
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
      final rule = MerchantCategoryService(firestore: _db).ruleFor(uid, sms);
      var selectedCategory = category;
      if (applyMerchantRule && existingId == null && rule != null) {
        final savedRule = (await transaction.get(rule)).data();
        if (savedRule != null && savedRule['enabled'] != false)
          selectedCategory = savedRule['category'] as String? ?? category;
      }
      if (existingId == null && assignedAccount != null) {
        final account = await transaction.get(
          _db
              .collection('users')
              .doc(uid)
              .collection('personal_accounts')
              .doc(assignedAccount),
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
