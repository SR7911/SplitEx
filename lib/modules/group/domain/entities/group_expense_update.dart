import 'group_expense_model.dart';

class GroupExpenseUpdate {
  final String title;
  final double amount;
  final String category;
  final String? notes;
  final String paidBy;
  final GroupSplitType splitType;
  final List<String> splitAmong;
  final Map<String, double>? customSplits;
  final DateTime date;

  const GroupExpenseUpdate({
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
    required this.paidBy,
    required this.splitType,
    required this.splitAmong,
    this.customSplits,
    required this.date,
  });
}
