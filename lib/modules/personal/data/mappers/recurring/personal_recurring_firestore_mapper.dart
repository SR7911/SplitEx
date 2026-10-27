import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/recurring/personal_recurring_entry.dart';
import '../../../domain/entities/transactions/personal_transaction.dart';

class PersonalRecurringFirestoreMapper {
  static PersonalRecurringEntry fromMap(Map<String, dynamic> map, String id) =>
      PersonalRecurringEntry(
        id: id,
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        category: map['category'] ?? 'Other',
        type: TransactionType.values.firstWhere(
          (value) => value.name == map['type'],
          orElse: () => TransactionType.expense,
        ),
        frequency: PersonalRecurringFrequency.values.firstWhere(
          (value) => value.name == map['frequency'],
          orElse: () => PersonalRecurringFrequency.monthly,
        ),
        dayOfMonth: map['dayOfMonth'] ?? 1,
        active: map['active'] ?? true,
        userId: map['userId'] ?? '',
        lastRunDate: (map['lastRunDate'] as Timestamp?)?.toDate(),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        editHistory: (map['editHistory'] as List<dynamic>? ?? [])
            .map((entry) => editFromMap(entry as Map<String, dynamic>))
            .toList(),
      );

  static PersonalRecurringEdit editFromMap(Map<String, dynamic> map) =>
      PersonalRecurringEdit(
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        category: map['category'] ?? 'Other',
        frequency: PersonalRecurringFrequency.values.firstWhere(
          (value) => value.name == map['frequency'],
          orElse: () => PersonalRecurringFrequency.monthly,
        ),
        dayOfMonth: map['dayOfMonth'] ?? 1,
        endDate: _historyDate(map['endDate']),
        editedAt: _historyDate(map['editedAt']) ?? DateTime.now(),
      );

  static DateTime? _historyDate(Object? raw) => raw == null
      ? null
      : raw is Timestamp
      ? raw.toDate()
      : DateTime.tryParse(raw.toString());

  static Map<String, dynamic> toMap(PersonalRecurringEntry entry) => {
    'title': entry.title,
    'amount': entry.amount,
    'category': entry.category,
    'type': entry.type.name,
    'frequency': entry.frequency.name,
    'dayOfMonth': entry.dayOfMonth,
    'active': entry.active,
    'userId': entry.userId,
    if (entry.createdAt != null)
      'createdAt': Timestamp.fromDate(entry.createdAt!),
    if (entry.lastRunDate != null)
      'lastRunDate': Timestamp.fromDate(entry.lastRunDate!),
    if (entry.endDate != null) 'endDate': Timestamp.fromDate(entry.endDate!),
    'editHistory': entry.editHistory.map(editToMap).toList(),
  };

  static Map<String, dynamic> editToMap(PersonalRecurringEdit edit) => {
    'title': edit.title,
    'amount': edit.amount,
    'category': edit.category,
    'frequency': edit.frequency.name,
    'dayOfMonth': edit.dayOfMonth,
    if (edit.endDate != null) 'endDate': Timestamp.fromDate(edit.endDate!),
    'editedAt': Timestamp.fromDate(edit.editedAt),
  };
}
