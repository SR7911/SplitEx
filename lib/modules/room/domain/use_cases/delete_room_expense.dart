import 'dart:async';
import 'package:intl/intl.dart';
import '../entities/activity_model.dart';
import '../entities/expense_model.dart';
import '../entities/room_activity_entry.dart';
import '../repositories/room_ledger_repository.dart';

class DeleteRoomExpense {
  final RoomLedgerRepository ledger;
  const DeleteRoomExpense(this.ledger);

  void call(String roomId, ExpenseModel expense, String userId) {
    unawaited(
      ledger.deleteExpense(
        roomId,
        expense.id,
        RoomActivityEntry(
          type: ActivityType.expenseDeleted,
          performedBy: userId,
          description: 'Deleted "${expense.title}"',
          metadata: {
            'title': expense.title,
            'amount': expense.amount,
            'category': expense.category,
            'paidBy': expense.paidBy,
            'splitAmong': expense.splitAmong,
            'date': DateFormat('dd MMM yyyy').format(expense.date),
          },
        ),
      ),
    );
  }
}
