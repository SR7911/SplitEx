import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { expense, income }
enum RecurringFrequency { weekly, monthly }
enum DebtType { lent, borrowed }

class PersonalTransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? notes;
  final String userId;
  final String month; // yyyy-MM
  final DateTime createdAt;
  // Debt tracking fields
  final DebtType? debtType;
  final String? personName;
  final bool isSettled;
  final double settledAmount;
  final List<Map<String, dynamic>> partialSettlements;

  const PersonalTransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.notes,
    required this.userId,
    required this.month,
    required this.createdAt,
    this.debtType,
    this.personName,
    this.isSettled = false,
    this.settledAmount = 0,
    this.partialSettlements = const [],
  });

  bool get hasDebt => debtType != null && personName != null && personName!.isNotEmpty;
  double get remainingAmount => amount - settledAmount;

  factory PersonalTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return PersonalTransactionModel(
      id: id,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      category: map['category'] ?? 'Other',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'],
      userId: map['userId'] ?? '',
      month: map['month'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      debtType: map['debtType'] != null
          ? DebtType.values.firstWhere((e) => e.name == map['debtType'], orElse: () => DebtType.lent)
          : null,
      personName: map['personName'],
      isSettled: map['isSettled'] ?? false,
      settledAmount: (map['settledAmount'] ?? 0).toDouble(),
      partialSettlements: List<Map<String, dynamic>>.from(map['partialSettlements'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'userId': userId,
      'month': month,
      'createdAt': FieldValue.serverTimestamp(),
      if (debtType != null) 'debtType': debtType!.name,
      if (personName != null) 'personName': personName,
      'isSettled': isSettled,
      'settledAmount': settledAmount,
      'partialSettlements': partialSettlements,
    };
  }

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
}

class CategoryBudget {
  final String id;
  final String category;
  final double budget;
  final String userId;
  final String month; // yyyy-MM

  const CategoryBudget({
    required this.id,
    required this.category,
    required this.budget,
    required this.userId,
    required this.month,
  });

  factory CategoryBudget.fromMap(Map<String, dynamic> map, String id) {
    return CategoryBudget(
      id: id,
      category: map['category'] ?? '',
      budget: (map['budget'] ?? 0).toDouble(),
      userId: map['userId'] ?? '',
      month: map['month'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'budget': budget,
      'userId': userId,
      'month': month,
    };
  }
}

class RecurringTransaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final TransactionType type;
  final RecurringFrequency frequency;
  final int dayOfMonth; // 1-31 for monthly
  final bool active;
  final String userId;
  final DateTime? lastRunDate;
  final DateTime? endDate;
  /// Snapshot of fields before each edit — newest first.
  final List<RecurringEditSnapshot> editHistory;

  const RecurringTransaction({
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
    this.editHistory = const [],
  });

  factory RecurringTransaction.fromMap(Map<String, dynamic> map, String id) {
    return RecurringTransaction(
      id: id,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      dayOfMonth: map['dayOfMonth'] ?? 1,
      active: map['active'] ?? true,
      userId: map['userId'] ?? '',
      lastRunDate: (map['lastRunDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      editHistory: (map['editHistory'] as List<dynamic>? ?? [])
          .map((e) => RecurringEditSnapshot.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'type': type.name,
      'frequency': frequency.name,
      'dayOfMonth': dayOfMonth,
      'active': active,
      'userId': userId,
      if (lastRunDate != null) 'lastRunDate': Timestamp.fromDate(lastRunDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'editHistory': editHistory.map((e) => e.toMap()).toList(),
    };
  }

  bool get isExpired {
    if (endDate == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !end.isAfter(today);
  }
}

/// Immutable snapshot of a RecurringTransaction's editable fields before an edit.
class RecurringEditSnapshot {
  final String title;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final int dayOfMonth;
  final DateTime? endDate;
  final DateTime editedAt;

  const RecurringEditSnapshot({
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.dayOfMonth,
    this.endDate,
    required this.editedAt,
  });

  factory RecurringEditSnapshot.fromMap(Map<String, dynamic> map) {
    return RecurringEditSnapshot(
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      dayOfMonth: map['dayOfMonth'] ?? 1,
      endDate: map['endDate'] != null
          ? (map['endDate'] is Timestamp
              ? (map['endDate'] as Timestamp).toDate()
              : DateTime.tryParse(map['endDate'].toString()))
          : null,
      editedAt: map['editedAt'] != null
          ? (map['editedAt'] is Timestamp
              ? (map['editedAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['editedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'category': category,
        'frequency': frequency.name,
        'dayOfMonth': dayOfMonth,
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'editedAt': Timestamp.fromDate(editedAt),
      };
}
