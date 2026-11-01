import 'package:intl/intl.dart';
import '../entities/activity_model.dart';
import '../entities/bill_model.dart';
import '../entities/room_activity_entry.dart';
import '../repositories/room_ledger_repository.dart';

class RecordRoomBill {
  final RoomLedgerRepository ledger;
  const RecordRoomBill(this.ledger);

  Future<void> call(String roomId, BillModel bill) => ledger.recordBill(
    roomId,
    bill,
    RoomActivityEntry(
      type: ActivityType.billAdded,
      performedBy: bill.paidBy,
      description: 'Added ${bill.typeName} bill: ₹${bill.amount}',
      metadata: {
        'title': bill.type.name,
        'amount': bill.amount,
        'category': bill.type.name,
        'paidBy': bill.paidBy,
        'splitAmong': bill.splitAmong,
        'date': DateFormat('dd MMM yyyy').format(bill.date),
        'type': bill.type.name,
      },
    ),
  );
}
