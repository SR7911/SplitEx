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
  });

  bool get hasDebt => debtType != null && personName != null && personName!.isNotEmpty;

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
    };
  }

  bool get isExpired {
    if (endDate == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !end.isAfter(today);
  }
}
