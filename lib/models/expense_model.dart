import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitType { equal, dynamic, oneToOne }

class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String paidBy;
  final SplitType splitType;
  final List<String> splitAmong;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String month;
  final String? receiptUrl;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.paidBy,
    required this.splitType,
    required this.splitAmong,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.month,
    this.receiptUrl,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidBy: map['paidBy'] ?? '',
      splitType: SplitType.values.firstWhere(
        (e) => e.name == map['splitType'],
        orElse: () => SplitType.equal,
      ),
      splitAmong: List<String>.from(map['splitAmong'] ?? []),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      month: map['month'] ?? '',
      receiptUrl: map['receiptUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'paidBy': paidBy,
      'splitType': splitType.name,
      'splitAmong': splitAmong,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'month': month,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'date': Timestamp.fromDate(date),
      'paidBy': paidBy,
      'splitType': splitType.name,
      'splitAmong': splitAmong,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  double get splitAmount {
    if (splitAmong.isEmpty) return amount;
    return amount / splitAmong.length;
  }
}
