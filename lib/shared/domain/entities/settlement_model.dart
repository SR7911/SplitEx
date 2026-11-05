enum SettlementStatus { pending, confirmed, cancelled }

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

  /// The expense month being settled, which may precede the payment date.
  final String? ledgerMonth;

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
    this.ledgerMonth,
  });

  String get effectiveMonth =>
      ledgerMonth ??
      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
}
