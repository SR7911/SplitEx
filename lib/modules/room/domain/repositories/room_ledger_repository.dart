import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import '../entities/bill_model.dart';
import '../entities/expense_model.dart';
import '../entities/room_activity_entry.dart';
import '../entities/room_expense_update.dart';

abstract interface class RoomLedgerRepository {
  Future<void> recordExpense(
    String roomId,
    ExpenseModel expense,
    RoomActivityEntry activity,
  );
  Future<void> editExpense(
    String roomId,
    String expenseId,
    RoomExpenseUpdate changes,
    RoomActivityEntry activity,
  );
  Future<void> deleteExpense(
    String roomId,
    String expenseId,
    RoomActivityEntry activity,
  );
  Future<void> recordBill(
    String roomId,
    BillModel bill,
    RoomActivityEntry activity,
  );
  Future<void> deleteBill(
    String roomId,
    String billId,
    RoomActivityEntry activity,
  );
  Future<String> recordSettlement(
    String roomId,
    SettlementModel settlement,
    RoomActivityEntry activity,
  );
  Future<void> confirmSettlement(
    String roomId,
    String settlementId,
    RoomActivityEntry activity,
  );
}
