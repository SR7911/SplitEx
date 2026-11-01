import 'package:intl/intl.dart';
import '../entities/activity_model.dart';
import '../entities/expense_model.dart';
import '../entities/room_activity_entry.dart';
import '../repositories/room_ledger_repository.dart';

class RecordRoomExpense {
  final RoomLedgerRepository ledger;
  const RecordRoomExpense(this.ledger);

  Future<void> call(
    String roomId,
    ExpenseModel expense,
  ) => ledger.recordExpense(
    roomId,
    expense,
    RoomActivityEntry(
      type: ActivityType.expenseAdded,
      performedBy: expense.createdBy,
      description:
          'Added "${expense.title}" for ₹${expense.amount.toStringAsFixed(0)}',
      metadata: {
        'title': expense.title,
        'amount': expense.amount,
        'category': expense.category,
        'paidBy': expense.paidBy,
        'splitAmong': expense.splitAmong,
        'date': DateFormat('dd MMM yyyy').format(expense.date),
      },
    ),
  );
}
