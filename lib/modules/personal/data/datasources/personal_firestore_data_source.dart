import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore paths and raw account-transfer write for the Personal module.
class PersonalFirestoreDataSource {
  final FirebaseFirestore db;
  const PersonalFirestoreDataSource(this.db);

  DocumentReference<Map<String, dynamic>> user(String uid) =>
      db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> transactions(String uid) =>
      user(uid).collection('personal_transactions');
  CollectionReference<Map<String, dynamic>> accounts(String uid) =>
      user(uid).collection('personal_accounts');
  CollectionReference<Map<String, dynamic>> transfers(String uid) =>
      user(uid).collection('personal_transfers');
  CollectionReference<Map<String, dynamic>> budgets(String uid) =>
      user(uid).collection('personal_budgets');
  CollectionReference<Map<String, dynamic>> recurring(String uid) =>
      user(uid).collection('personal_recurring');
  CollectionReference<Map<String, dynamic>> loans(String uid) =>
      user(uid).collection('loans');
  CollectionReference<Map<String, dynamic>> savingsGoals(String uid) =>
      user(uid).collection('personal_savings_goals');
  CollectionReference<Map<String, dynamic>> merchantRules(String uid) =>
      user(uid).collection('merchant_category_rules');
  CollectionReference<Map<String, dynamic>> smsReceipts(String uid) =>
      user(uid).collection('bank_sms_receipts');

  Future<void> saveTransfer(
    String uid,
    String transferId,
    String fromAccountId,
    String toAccountId,
    Map<String, dynamic> data,
  ) async {
    final target = transferId.isEmpty
        ? transfers(uid).doc()
        : transfers(uid).doc(transferId);
    await db.runTransaction((transaction) async {
      final from = await transaction.get(accounts(uid).doc(fromAccountId));
      final to = await transaction.get(accounts(uid).doc(toAccountId));
      if (!from.exists ||
          !to.exists ||
          from.data()?['archived'] == true ||
          to.data()?['archived'] == true) {
        throw StateError('Both accounts must be available and active.');
      }
      transaction.set(target, data);
    });
  }
}
