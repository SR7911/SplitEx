import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/data/mappers/recurring/personal_recurring_firestore_mapper.dart';
import 'package:split_ex/modules/personal/domain/repositories/personal_recurring_processor.dart';
import 'package:split_ex/modules/personal/domain/repositories/personal_transaction_repository.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/create_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/recurring/recurring_due_dates.dart';

class FirestorePersonalRecurringProcessor
    implements PersonalRecurringProcessor {
  final FirebaseFirestore _firestore;
  final PersonalTransactionRepository _transactions;
  final DateTime Function() _clock;

  FirestorePersonalRecurringProcessor({
    required FirebaseFirestore firestore,
    required PersonalTransactionRepository transactions,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _transactions = transactions,
       _clock = clock ?? DateTime.now;

  /// Call on app open. Checks all active recurring entries and creates
  /// transactions for any missed dates since lastRunDate.
  @override
  Future<void> processRecurring(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_recurring')
        .where('active', isEqualTo: true)
        .get();

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in snap.docs) {
      final r = PersonalRecurringFirestoreMapper.fromMap(doc.data(), doc.id);
      if (r.isExpiredAt(today)) continue;
      final dueDates = recurringDueDatesSince(r, today);

      for (final dueDate in dueDates) {
        final txn = PersonalTransaction(
          id: '',
          title: '${r.title} (auto)',
          amount: r.amount,
          type: r.type,
          category: r.category,
          date: dueDate,
          notes: 'Auto-added from recurring',
          userId: userId,
          month: '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}',
          createdAt: _clock(),
        );
        await CreatePersonalTransaction(_transactions)(userId, txn);
      }

      // Update lastRunDate
      if (dueDates.isNotEmpty) {
        await doc.reference.update({
          'lastRunDate': Timestamp.fromDate(dueDates.last),
        });
      }
    }
  }
}
