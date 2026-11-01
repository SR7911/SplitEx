import 'expense_model.dart';

class RoomExpenseUpdate {
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final SplitType splitType;
  final List<String> splitAmong;
  final String month;

  const RoomExpenseUpdate({
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.splitType,
    required this.splitAmong,
    required this.month,
  });
}
