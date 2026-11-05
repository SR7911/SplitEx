import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

class SettlementFirestoreMapper {
  static SettlementModel fromMap(Map<String, dynamic> map, String id) =>
      SettlementModel(
        id: id,
        roomId: map['roomId'] ?? '',
        fromUserId: map['fromUserId'] ?? '',
        toUserId: map['toUserId'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        status: SettlementStatus.values.firstWhere(
          (value) => value.name == map['status'],
          orElse: () => SettlementStatus.pending,
        ),
        upiRef: map['upiRef'],
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
        ledgerMonth: map['ledgerMonth'],
      );

  static Map<String, dynamic> toMap(SettlementModel settlement) => {
    'roomId': settlement.roomId,
    'fromUserId': settlement.fromUserId,
    'toUserId': settlement.toUserId,
    'amount': settlement.amount,
    'status': settlement.status.name,
    'upiRef': settlement.upiRef,
    'createdAt': FieldValue.serverTimestamp(),
    if (settlement.ledgerMonth != null) 'ledgerMonth': settlement.ledgerMonth,
  };
}
