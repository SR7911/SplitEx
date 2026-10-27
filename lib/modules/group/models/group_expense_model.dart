import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupSplitType { equal, percentage, custom, shares, selected }

class GroupExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String category;
  final String? notes;
  final String paidBy;
  final GroupSplitType splitType;
  final List<String> splitAmong;
  final Map<String, double>? customSplits; // uid -> amount for custom/percentage
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GroupExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
    required this.paidBy,
    required this.splitType,
    required this.splitAmong,
    this.customSplits,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  double shareFor(String uid) {
    if (!splitAmong.contains(uid)) return 0;
    if (customSplits != null && customSplits!.containsKey(uid)) {
      return customSplits![uid]!;
    }
    return splitAmong.isEmpty ? 0 : amount / splitAmong.length;
  }

  factory GroupExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupExpenseModel(
      id: id,
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      notes: map['notes'],
      paidBy: map['paidBy'] ?? '',
      splitType: GroupSplitType.values.firstWhere(
        (e) => e.name == map['splitType'],
        orElse: () => GroupSplitType.equal,
      ),
      splitAmong: List<String>.from(map['splitAmong'] ?? []),
      customSplits: map['customSplits'] != null
          ? Map<String, double>.from(
              (map['customSplits'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : null,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'title': title,
        'amount': amount,
        'category': category,
        'notes': notes,
        'paidBy': paidBy,
        'splitType': splitType.name,
        'splitAmong': splitAmong,
        if (customSplits != null) 'customSplits': customSplits,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'title': title,
        'amount': amount,
        'category': category,
        'notes': notes,
        'paidBy': paidBy,
        'splitType': splitType.name,
        'splitAmong': splitAmong,
        if (customSplits != null) 'customSplits': customSplits,
        'date': Timestamp.fromDate(date),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}