import 'package:intl/intl.dart';
import '../entities/activity_model.dart';
import '../entities/expense_model.dart';
import '../entities/room_activity_entry.dart';
import '../entities/room_expense_update.dart';
import '../repositories/room_ledger_repository.dart';

class EditRoomExpense {
  final RoomLedgerRepository ledger;
  const EditRoomExpense(this.ledger);

  Future<void> call(
    String roomId,
    ExpenseModel original,
    RoomExpenseUpdate changes,
    String userId,
  ) => ledger.editExpense(
    roomId,
    original.id,
    changes,
    RoomActivityEntry(
      type: ActivityType.expenseEdited,
      performedBy: userId,
      description: 'Edited "${changes.title}"',
      metadata: {
        'title': changes.title,
        'amount': changes.amount,
        'category': changes.category,
        'paidBy': original.paidBy,
        'splitAmong': changes.splitAmong,
        'date': DateFormat('dd MMM yyyy').format(changes.date),
      },
    ),
  );
}
