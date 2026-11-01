import 'expense_model.dart';

class DebtTransaction {
  final String id;
  final String title;
  final DateTime date;
  final double totalAmount;
  final double userShare;
  final String paidBy;
  final List<String> splitAmong;
  final SplitType splitType;
  final bool isBill;

  const DebtTransaction({
    required this.id,
    required this.title,
    required this.date,
    required this.totalAmount,
    required this.userShare,
    required this.paidBy,
    required this.splitAmong,
    required this.splitType,
    required this.isBill,
  });
}
