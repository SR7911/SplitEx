import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_entry.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/recurring/recurring_due_dates.dart';

void main() {
  PersonalRecurringEntry entry(
    PersonalRecurringFrequency frequency, {
    DateTime? lastRun,
    DateTime? endDate,
    int day = 1,
  }) => PersonalRecurringEntry(
    id: 'r-1',
    title: 'Rent',
    amount: 100,
    category: 'Rent',
    type: TransactionType.expense,
    frequency: frequency,
    dayOfMonth: day,
    active: true,
    userId: 'alice',
    lastRunDate: lastRun,
    endDate: endDate,
  );

  test('monthly catch-up clamps day 31 in shorter months', () {
    final dates = recurringDueDatesSince(
      entry(
        PersonalRecurringFrequency.monthly,
        lastRun: DateTime(2025, 1, 31),
        day: 31,
      ),
      DateTime(2025, 3, 31),
    );
    expect(dates, [DateTime(2025, 2, 28), DateTime(2025, 3, 31)]);
  });

  test('weekly catch-up respects end date', () {
    final dates = recurringDueDatesSince(
      entry(
        PersonalRecurringFrequency.weekly,
        lastRun: DateTime(2025, 8, 1),
        endDate: DateTime(2025, 8, 17),
      ),
      DateTime(2025, 8, 30),
    );
    expect(dates, [DateTime(2025, 8, 8), DateTime(2025, 8, 15)]);
  });
}
