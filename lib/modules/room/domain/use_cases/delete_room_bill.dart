import 'dart:async';
import 'package:intl/intl.dart';
import '../entities/activity_model.dart';
import '../entities/bill_model.dart';
import '../entities/room_activity_entry.dart';
import '../repositories/room_ledger_repository.dart';

class DeleteRoomBill {
  final RoomLedgerRepository ledger;
  const DeleteRoomBill(this.ledger);

  void call(String roomId, BillModel bill, String userId) {
    unawaited(
      ledger.deleteBill(
        roomId,
        bill.id,
        RoomActivityEntry(
          type: ActivityType.expenseDeleted,
          performedBy: userId,
          description: 'Deleted "${bill.typeName}"',
          metadata: {
            'title': bill.typeName,
            'amount': bill.amount,
            'paidBy': bill.paidBy,
            'splitAmong': bill.splitAmong,
            'date': DateFormat('dd MMM yyyy').format(bill.date),
          },
        ),
      ),
    );
  }
}
