import '../transactions/personal_transaction.dart';

enum PersonalRecurringFrequency { weekly, monthly }

class PersonalRecurringEdit {
  final String title;
  final double amount;
  final String category;
  final PersonalRecurringFrequency frequency;
  final int dayOfMonth;
  final DateTime? endDate;
  final DateTime editedAt;

  const PersonalRecurringEdit({
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.dayOfMonth,
    this.endDate,
    required this.editedAt,
  });
}

class PersonalRecurringEntry {
  final String id;
  final String title;
  final double amount;
  final String category;
  final TransactionType type;
  final PersonalRecurringFrequency frequency;
  final int dayOfMonth;
  final bool active;
  final String userId;
  final DateTime? lastRunDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final List<PersonalRecurringEdit> editHistory;

  const PersonalRecurringEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.frequency,
    required this.dayOfMonth,
    required this.active,
    required this.userId,
    this.lastRunDate,
    this.endDate,
    this.createdAt,
    this.editHistory = const [],
  });

  bool isExpiredAt(DateTime now) {
    if (endDate == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !end.isAfter(today);
  }

  bool get isExpired => isExpiredAt(DateTime.now());
}
