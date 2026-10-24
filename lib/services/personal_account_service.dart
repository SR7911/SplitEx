import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/personal_account_model.dart';
import 'package:split_ex/models/personal_transaction_model.dart';

class PersonalAccountService {
  final FirebaseFirestore db;
  PersonalAccountService({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _accounts(String uid) =>
      db.collection('users').doc(uid).collection('personal_accounts');
  CollectionReference<Map<String, dynamic>> _transfers(String uid) =>
      db.collection('users').doc(uid).collection('personal_transfers');

  Stream<List<PersonalAccount>> accounts(String uid) =>
      _accounts(uid).snapshots().map(
        (s) =>
            s.docs.map((d) => PersonalAccount.fromMap(d.data(), d.id)).toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
      );
  Stream<List<PersonalTransfer>> transfers(String uid) =>
      _transfers(uid).snapshots().map(
        (s) =>
            s.docs.map((d) => PersonalTransfer.fromMap(d.data(), d.id)).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );
  Stream<List<PersonalTransactionModel>> assignedTransactions(String uid) => db
      .collection('users')
      .doc(uid)
      .collection('personal_transactions')
      .where('accountId', isGreaterThan: '')
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => PersonalTransactionModel.fromMap(d.data(), d.id))
            .toList(),
      );

  Future<void> saveAccount(String uid, PersonalAccount account) async {
    if (account.name.trim().isEmpty ||
        !account.openingBalance.isFinite ||
        (account.last4 != null &&
            !RegExp(r'^\d{4}$').hasMatch(account.last4!))) {
      throw StateError(
        'Enter an account name, valid balance and four-digit ending.',
      );
    }
    final data = account.toMap();
    data['openingBalance'] = (account.openingBalance * 100).round() / 100;
    if (account.id.isEmpty) {
      await _accounts(
        uid,
      ).add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _accounts(uid).doc(account.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> archive(String uid, String id, bool archived) =>
      _accounts(uid).doc(id).update({'archived': archived});

  Future<void> saveTransfer(String uid, PersonalTransfer transfer) async {
    if (transfer.fromAccountId == transfer.toAccountId ||
        !transfer.amount.isFinite ||
        transfer.amount <= 0 ||
        (transfer.amount * 100).round() == 0) {
      throw StateError('Choose different accounts and a positive amount.');
    }
    final target = transfer.id.isEmpty
        ? _transfers(uid).doc()
        : _transfers(uid).doc(transfer.id);
    await db.runTransaction((tx) async {
      final from = await tx.get(_accounts(uid).doc(transfer.fromAccountId));
      final to = await tx.get(_accounts(uid).doc(transfer.toAccountId));
      if (!from.exists ||
          !to.exists ||
          from.data()?['archived'] == true ||
          to.data()?['archived'] == true) {
        throw StateError('Both accounts must be available and active.');
      }
      tx.set(target, {
        ...transfer.toMap(),
        'amount': (transfer.amount * 100).round() / 100,
      });
    });
  }

  Future<void> deleteTransfer(String uid, String id) =>
      _transfers(uid).doc(id).delete();
}
