import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import '../entities/activity_model.dart';
import '../entities/room_activity_entry.dart';
import '../repositories/room_ledger_repository.dart';

class RecordRoomSettlement {
  final RoomLedgerRepository ledger;
  const RecordRoomSettlement(this.ledger);

  Future<String> call(
    String roomId,
    SettlementModel settlement, {
    required String payerName,
    required String payeeName,
  }) => ledger.recordSettlement(
    roomId,
    settlement,
    RoomActivityEntry(
      type: ActivityType.settlementCreated,
      performedBy: settlement.fromUserId,
      description:
          '$payerName paid ₹${settlement.amount.toStringAsFixed(0)} to $payeeName',
      metadata: {
        'amount': settlement.amount,
        'from': settlement.fromUserId,
        'to': settlement.toUserId,
      },
    ),
  );
}
