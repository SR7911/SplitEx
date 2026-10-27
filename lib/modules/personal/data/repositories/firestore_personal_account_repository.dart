import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/accounts/personal_account.dart';
import '../../domain/entities/accounts/personal_transfer.dart';
import '../../domain/entities/transactions/personal_transaction.dart';
import '../../domain/policies/accounts/account_validation.dart';
import '../../domain/repositories/personal_account_repository.dart';
import '../mappers/accounts/account_firestore_mapper.dart';
import '../mappers/transactions/personal_transaction_firestore_mapper.dart';

class FirestorePersonalAccountRepository implements PersonalAccountRepository {
  final FirebaseFirestore _db;
  FirestorePersonalAccountRepository({required FirebaseFirestore firestore})
    : _db = firestore;

  CollectionReference<Map<String, dynamic>> _accounts(String uid) =>
      _db.collection('users').doc(uid).collection('personal_accounts');
  CollectionReference<Map<String, dynamic>> _transfers(String uid) =>
      _db.collection('users').doc(uid).collection('personal_transfers');

  @override
  Stream<List<PersonalAccount>> accounts(String userId) =>
      _accounts(userId).snapshots().map(
        (snapshot) =>
            snapshot.docs
                .map(
                  (doc) => AccountFirestoreMapper.fromMap(doc.data(), doc.id),
                )
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ),
      );

  @override
  Stream<List<PersonalTransfer>> transfers(String userId) =>
      _transfers(userId).snapshots().map(
        (snapshot) =>
            snapshot.docs
                .map(
                  (doc) => TransferFirestoreMapper.fromMap(doc.data(), doc.id),
                )
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  Stream<List<PersonalTransaction>> assignedTransactions(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('personal_transactions')
      .where('accountId', isGreaterThan: '')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => PersonalTransactionFirestoreMapper.fromMap(
                doc.data(),
                doc.id,
              ),
            )
            .toList(),
      );

  @override
  Future<void> saveAccount(String userId, PersonalAccount account) async {
    // Keep validation for legacy direct callers as well as domain use cases.
    validatePersonalAccount(account);
    final data = AccountFirestoreMapper.toMap(account);
    data['openingBalance'] = (account.openingBalance * 100).round() / 100;
    if (account.id.isEmpty) {
      await _accounts(
        userId,
      ).add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _accounts(
        userId,
      ).doc(account.id).set(data, SetOptions(merge: true));
    }
  }

  @override
  Future<void> archive(String userId, String id, bool archived) =>
      _accounts(userId).doc(id).update({'archived': archived});

  @override
  Future<void> saveTransfer(String userId, PersonalTransfer transfer) async {
    validatePersonalTransfer(transfer);
    final target = transfer.id.isEmpty
        ? _transfers(userId).doc()
        : _transfers(userId).doc(transfer.id);
    await _db.runTransaction((transaction) async {
      final from = await transaction.get(
        _accounts(userId).doc(transfer.fromAccountId),
      );
      final to = await transaction.get(
        _accounts(userId).doc(transfer.toAccountId),
      );
      if (!from.exists ||
          !to.exists ||
          from.data()?['archived'] == true ||
          to.data()?['archived'] == true) {
        throw StateError('Both accounts must be available and active.');
      }
      transaction.set(target, {
        ...TransferFirestoreMapper.toMap(transfer),
        'amount': (transfer.amount * 100).round() / 100,
      });
    });
  }

  @override
  Future<void> deleteTransfer(String userId, String id) =>
      _transfers(userId).doc(id).delete();
}
