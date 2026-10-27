import 'personal_recurring_entry.dart';

/// Optional values supplied while editing an existing recurring entry.
class PersonalRecurringChanges {
  final String? title;
  final double? amount;
  final String? category;
  final PersonalRecurringFrequency? frequency;
  final int? dayOfMonth;
  final DateTime? endDate;
  final bool clearEndDate;

  const PersonalRecurringChanges({
    this.title,
    this.amount,
    this.category,
    this.frequency,
    this.dayOfMonth,
    this.endDate,
    this.clearEndDate = false,
  });
}
