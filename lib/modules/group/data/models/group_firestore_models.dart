import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/group/domain/entities/group_model.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_model.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_update.dart';

class GroupFirestoreMapper {
  static GroupModel fromMap(Map<String, dynamic> map, String id) => GroupModel(
    id: id,
    name: map['name'] ?? '',
    description: map['description'],
    startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    endDate: (map['endDate'] as Timestamp?)?.toDate(),
    currency: map['currency'] ?? '₹',
    inviteCode: map['inviteCode'] ?? '',
    createdBy: map['createdBy'] ?? '',
    memberIds: List<String>.from(map['memberIds'] ?? []),
    status: GroupStatus.values.firstWhere(
      (value) => value.name == map['status'],
      orElse: () => GroupStatus.active,
    ),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  static Map<String, dynamic> toMap(GroupModel group) => {
    'name': group.name,
    'description': group.description,
    'startDate': Timestamp.fromDate(group.startDate),
    'endDate': group.endDate != null
        ? Timestamp.fromDate(group.endDate!)
        : null,
    'currency': group.currency,
    'inviteCode': group.inviteCode,
    'createdBy': group.createdBy,
    'memberIds': group.memberIds,
    'status': group.status.name,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class GroupExpenseFirestoreMapper {
  static GroupExpenseModel fromMap(Map<String, dynamic> map, String id) =>
      GroupExpenseModel(
        id: id,
        groupId: map['groupId'] ?? '',
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        category: map['category'] ?? 'Other',
        notes: map['notes'],
        paidBy: map['paidBy'] ?? '',
        splitType: GroupSplitType.values.firstWhere(
          (value) => value.name == map['splitType'],
          orElse: () => GroupSplitType.equal,
        ),
        splitAmong: List<String>.from(map['splitAmong'] ?? []),
        customSplits: map['customSplits'] != null
            ? Map<String, double>.from(
                (map['customSplits'] as Map).map(
                  (key, value) =>
                      MapEntry(key as String, (value as num).toDouble()),
                ),
              )
            : null,
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdBy: map['createdBy'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      );

  static Map<String, dynamic> toMap(GroupExpenseModel expense) => {
    'groupId': expense.groupId,
    'title': expense.title,
    'amount': expense.amount,
    'category': expense.category,
    'notes': expense.notes,
    'paidBy': expense.paidBy,
    'splitType': expense.splitType.name,
    'splitAmong': expense.splitAmong,
    if (expense.customSplits != null) 'customSplits': expense.customSplits,
    'date': Timestamp.fromDate(expense.date),
    'createdBy': expense.createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static Map<String, dynamic> toUpdateMap(GroupExpenseUpdate changes) => {
    'title': changes.title,
    'amount': changes.amount,
    'category': changes.category,
    'notes': changes.notes,
    'paidBy': changes.paidBy,
    'splitType': changes.splitType.name,
    'splitAmong': changes.splitAmong,
    if (changes.customSplits != null) 'customSplits': changes.customSplits,
    'date': Timestamp.fromDate(changes.date),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
