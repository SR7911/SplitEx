import 'package:cloud_firestore/cloud_firestore.dart';

enum SettlementStatus { pending, confirmed }

class SettlementModel {
  final String id;
  final String roomId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final SettlementStatus status;
  final String? upiRef;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const SettlementModel({
    required this.id,
    required this.roomId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.status = SettlementStatus.pending,
    this.upiRef,
    required this.createdAt,
    this.confirmedAt,
  });

  factory SettlementModel.fromMap(Map<String, dynamic> map, String id) {
    return SettlementModel(
      id: id,
      roomId: map['roomId'] ?? '',
      fromUserId: map['fromUserId'] ?? '',
      toUserId: map['toUserId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: SettlementStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SettlementStatus.pending,
      ),
      upiRef: map['upiRef'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'status': status.name,
      'upiRef': upiRef,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
