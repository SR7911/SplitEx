enum GroupSplitType { equal, percentage, custom, shares, selected }

class GroupExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String category;
  final String? notes;
  final String paidBy;
  final GroupSplitType splitType;
  final List<String> splitAmong;
  final Map<String, double>?
  customSplits; // uid -> amount for custom/percentage
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GroupExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
    required this.paidBy,
    required this.splitType,
    required this.splitAmong,
    this.customSplits,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  double shareFor(String uid) {
    if (!splitAmong.contains(uid)) return 0;
    if (customSplits != null && customSplits!.containsKey(uid)) {
      return customSplits![uid]!;
    }
    return splitAmong.isEmpty ? 0 : amount / splitAmong.length;
  }
}
