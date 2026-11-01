
enum SplitType { equal, dynamic, oneToOne }

class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String paidBy;
  final SplitType splitType;
  final List<String> splitAmong;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String month;
  final String? receiptUrl;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.paidBy,
    required this.splitType,
    required this.splitAmong,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.month,
    this.receiptUrl,
  });

  double get splitAmount {
    if (splitAmong.isEmpty) return amount;
    return amount / splitAmong.length;
  }
}
