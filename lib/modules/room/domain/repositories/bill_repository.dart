import '../entities/bill_model.dart';
import '../entities/room_bill_update.dart';

abstract interface class BillRepository {
  Future<void> addBill(String roomId, BillModel bill);
  Future<void> updateBill(String roomId, String billId, RoomBillUpdate changes);
  Future<void> deleteBill(String roomId, String billId);
  Stream<List<BillModel>> getBillsStream(String roomId, String month);
}
