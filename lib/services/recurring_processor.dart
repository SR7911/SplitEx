import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/services/personal_expense_service.dart';

class RecurringProcessor {
  final PersonalExpenseService _service = PersonalExpenseService();
  final _firestore = FirebaseFirestore.instance;

  /// Call on app open. Checks all active recurring entries and creates
  /// transactions for any missed dates since lastRunDate.
  Future<void> processRecurring(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_recurring')
        .where('active', isEqualTo: true)
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in snap.docs) {
      final r = RecurringTransaction.fromMap(doc.data(), doc.id);
      if (r.isExpired) continue;
      final dueDates = _getDueDatesSince(r, today);

      for (final dueDate in dueDates) {
        final txn = PersonalTransactionModel(
          id: '',
          title: '${r.title} (auto)',
          amount: r.amount,
          type: r.type,
          category: r.category,
          date: dueDate,
          notes: 'Auto-added from recurring',
          userId: userId,
          month: DateFormat('yyyy-MM').format(dueDate),
          createdAt: DateTime.now(),
        );
        await _service.addTransaction(userId, txn);
      }

      // Update lastRunDate
      if (dueDates.isNotEmpty) {
        await doc.reference.update({
          'lastRunDate': Timestamp.fromDate(dueDates.last),
        });
      }
    }
  }

  /// Returns all due dates between lastRunDate and today (inclusive).
  /// Respects endDate if set.
  List<DateTime> _getDueDatesSince(RecurringTransaction r, DateTime today) {
    final dates = <DateTime>[];
    final lastRun = r.lastRunDate;
    final endLimit = r.endDate != null && r.endDate!.isBefore(today) ? r.endDate! : today;

    if (r.frequency == RecurringFrequency.monthly) {
      // Start from the month after lastRun (or current month if no lastRun)
      DateTime cursor;
      if (lastRun == null) {
        cursor = DateTime(endLimit.year, endLimit.month, r.dayOfMonth);
        if (cursor.isAfter(endLimit)) return dates;
        dates.add(cursor);
        return dates;
      }

      cursor = DateTime(lastRun.year, lastRun.month + 1, 1);
      while (true) {
        final day = r.dayOfMonth.clamp(1, _daysInMonth(cursor.year, cursor.month));
        final dueDate = DateTime(cursor.year, cursor.month, day);
        if (dueDate.isAfter(endLimit)) break;
        dates.add(dueDate);
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } else if (r.frequency == RecurringFrequency.weekly) {
      DateTime cursor;
      if (lastRun == null) {
        cursor = endLimit;
        dates.add(cursor);
        return dates;
      }

      cursor = lastRun.add(const Duration(days: 7));
      while (!cursor.isAfter(endLimit)) {
        dates.add(cursor);
        cursor = cursor.add(const Duration(days: 7));
      }
    }

    return dates;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
