import 'package:cloud_firestore/cloud_firestore.dart';

enum BillType { rent, electricity, water }

class BillModel {
  final String id;
  final BillType type;
  final double amount;
  final String paidBy;
  final String month;
  final DateTime date;
  final String? receiptUrl;
  final DateTime createdAt;

  const BillModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.paidBy,
    required this.month,
    required this.date,
    this.receiptUrl,
    required this.createdAt,
  });

  String get typeName => switch (type) {
        BillType.rent => 'Rent',
        BillType.electricity => 'Electricity',
        BillType.water => 'Water',
      };

  factory BillModel.fromMap(Map<String, dynamic> map, String id) {
    return BillModel(
      id: id,
      type: BillType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BillType.rent,
      ),
      amount: (map['amount'] ?? 0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      month: map['month'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      receiptUrl: map['receiptUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'amount': amount,
      'paidBy': paidBy,
      'month': month,
      'date': Timestamp.fromDate(date),
      'receiptUrl': receiptUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
