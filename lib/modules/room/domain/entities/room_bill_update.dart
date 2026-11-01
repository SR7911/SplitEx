import 'bill_model.dart';

class RoomBillUpdate {
  final BillType type;
  final double amount;
  final DateTime date;
  final String month;

  const RoomBillUpdate({
    required this.type,
    required this.amount,
    required this.date,
    required this.month,
  });
}
