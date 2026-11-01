import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import '../entities/activity_model.dart';
import '../entities/room_activity_entry.dart';
import '../repositories/room_ledger_repository.dart';

class ConfirmRoomSettlement {
  final RoomLedgerRepository ledger;
  const ConfirmRoomSettlement(this.ledger);

  Future<void> call(
    String roomId,
    SettlementModel settlement,
    String userId, {
    required String payerName,
    required String payeeName,
  }) => ledger.confirmSettlement(
    roomId,
    settlement.id,
    RoomActivityEntry(
      type: ActivityType.settlementConfirmed,
      performedBy: userId,
      description:
          '$payeeName confirmed settlement from $payerName of ₹${settlement.amount.toStringAsFixed(0)}',
      metadata: {'settlementId': settlement.id},
    ),
  );
}
