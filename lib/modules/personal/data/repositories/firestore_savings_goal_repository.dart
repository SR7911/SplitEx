import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/personal/data/mappers/savings/savings_goal_firestore_mapper.dart';
import 'package:split_ex/modules/personal/domain/entities/savings/savings_goal.dart';
import 'package:split_ex/modules/personal/domain/repositories/savings_goal_repository.dart';

class FirestoreSavingsGoalRepository implements SavingsGoalRepository {
  final FirebaseFirestore db;
  FirestoreSavingsGoalRepository({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> goals(String uid) =>
      db.collection('users').doc(uid).collection('personal_savings_goals');
  @override
  Stream<List<SavingsGoal>> watch(String uid) => goals(uid).snapshots().map(
    (s) => s.docs.map((d) => savingsGoalFromFirestore(d.data(), d.id)).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
  );
  @override
  Stream<List<SavingsEntry>> entries(String uid, String goalId) => goals(uid)
      .doc(goalId)
      .collection('entries')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => savingsEntryFromFirestore(d.data(), d.id)).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );
  @override
  Future<void> save(String uid, SavingsGoal goal) async {
    if (goal.id.isEmpty || goal.title.trim().isEmpty || goal.targetMinor <= 0)
      throw StateError('Enter a goal name and positive target.');
    final target = goals(uid).doc(goal.id);
    await db.runTransaction((tx) async {
      final current = await tx.get(target);
      if (goal.accountId != null &&
          goal.accountId != current.data()?['accountId']) {
        final account = await tx.get(
          db
              .collection('users')
              .doc(uid)
              .collection('personal_accounts')
              .doc(goal.accountId),
        );
        if (!account.exists || account.data()?['archived'] == true)
          throw StateError('Choose an active account.');
      }
      tx.set(target, {
        'title': goal.title.trim(),
        'targetMinor': goal.targetMinor,
        'savedMinor': current.data()?['savedMinor'] ?? 0,
        'targetDate': goal.targetDate == null
            ? null
            : Timestamp.fromDate(goal.targetDate!),
        'accountId': goal.accountId,
        'archived': current.data()?['archived'] ?? false,
        if (!current.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> archive(String uid, String id, bool archived) =>
      goals(uid).doc(id).update({'archived': archived});
  @override
  Future<void> record(String uid, String goalId, SavingsEntry entry) async {
    if (entry.id.isEmpty || entry.amountMinor == 0)
      throw StateError('Enter a positive amount.');
    final goal = goals(uid).doc(goalId);
    final target = goal.collection('entries').doc(entry.id);
    await db.runTransaction((tx) async {
      final current = await tx.get(goal);
      final previous = await tx.get(target);
      if (previous.exists) return; // Stable IDs make retries idempotent.
      if (!current.exists || current.data()?['archived'] == true)
        throw StateError('Restore this goal before recording savings.');
      final next =
          (current.data()!['savedMinor'] as num).toInt() + entry.amountMinor;
      if (next < 0) throw StateError('Withdrawal exceeds the amount saved.');
      tx.set(target, {
        'amountMinor': entry.amountMinor,
        'date': Timestamp.fromDate(entry.date),
        'note': entry.note.trim(),
      });
      tx.update(goal, {'savedMinor': next});
    });
  }

  @override
  Future<void> removeEntry(String uid, String goalId, String entryId) async {
    final goal = goals(uid).doc(goalId);
    final target = goal.collection('entries').doc(entryId);
    await db.runTransaction((tx) async {
      final current = await tx.get(goal);
      final previous = await tx.get(target);
      if (!previous.exists) return;
      if (!current.exists || current.data()?['archived'] == true)
        throw StateError('Restore this goal before changing its history.');
      final next =
          (current.data()!['savedMinor'] as num).toInt() -
          (previous.data()!['amountMinor'] as num).toInt();
      if (next < 0)
        throw StateError(
          'Remove later withdrawals before deleting this contribution.',
        );
      tx.delete(target);
      tx.update(goal, {'savedMinor': next});
    });
  }
}
