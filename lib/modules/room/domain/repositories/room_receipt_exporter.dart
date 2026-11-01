import 'package:split_ex/shared/domain/entities/debt.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/debt_transaction.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';

abstract interface class RoomReceiptExporter {
  Future<String> generateMonthlyReceiptPath({
    required String roomName,
    required String month,
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required Map<String, String> nameMap,
    required List<Debt> debts,
    required int memberCount,
    Map<String, Map<String, List<DebtTransaction>>>? detailedDebtsMap,
    List<String>? memberIds,
  });

  Future<void> sharePdfPath(String path, {String? text});
}
