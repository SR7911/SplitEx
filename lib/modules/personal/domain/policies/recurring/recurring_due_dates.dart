import '../../entities/recurring/personal_recurring_entry.dart';

/// Existing catch-up schedule used when the app opens.
List<DateTime> recurringDueDatesSince(
  PersonalRecurringEntry entry,
  DateTime today,
) {
  final dates = <DateTime>[];
  final lastRun = entry.lastRunDate;
  final endLimit = entry.endDate != null && entry.endDate!.isBefore(today)
      ? entry.endDate!
      : today;

  if (entry.frequency == PersonalRecurringFrequency.monthly) {
    DateTime cursor;
    if (lastRun == null) {
      cursor = DateTime(endLimit.year, endLimit.month, entry.dayOfMonth);
      if (cursor.isAfter(endLimit)) return dates;
      dates.add(cursor);
      return dates;
    }
    cursor = DateTime(lastRun.year, lastRun.month + 1, 1);
    while (true) {
      final day = entry.dayOfMonth.clamp(
        1,
        DateTime(cursor.year, cursor.month + 1, 0).day,
      );
      final dueDate = DateTime(cursor.year, cursor.month, day);
      if (dueDate.isAfter(endLimit)) break;
      dates.add(dueDate);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  } else if (entry.frequency == PersonalRecurringFrequency.weekly) {
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
