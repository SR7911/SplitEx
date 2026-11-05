import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/modules/room/domain/entities/room_bill_update.dart';

class RoomFirestoreMapper {
  static RoomModel fromMap(Map<String, dynamic> map, String id) => RoomModel(
    id: id,
    name: map['name'] ?? '',
    inviteCode: map['inviteCode'] ?? '',
    adminId: map['adminId'] ?? '',
    memberIds: List<String>.from(map['memberIds'] ?? []),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    currentMonth: map['currentMonth'] ?? '',
    isLocked: map['isLocked'] ?? false,
    participantIds: List<String>.from(
      map['participantIds'] ?? map['memberIds'] ?? [],
    ),
    legacyBillMemberIds: map['legacyBillMemberIds'] == null
        ? null
        : List<String>.from(map['legacyBillMemberIds']),
    isArchived: map['isArchived'] ?? false,
  );

  static Map<String, dynamic> toMap(RoomModel room) => {
    'name': room.name,
    'inviteCode': room.inviteCode,
    'adminId': room.adminId,
    'memberIds': room.memberIds,
    'createdAt': FieldValue.serverTimestamp(),
    'currentMonth': room.currentMonth,
    'isLocked': room.isLocked,
    'participantIds': room.historicalMemberIds,
    'isArchived': room.isArchived,
    if (room.legacyBillMemberIds != null)
      'legacyBillMemberIds': room.legacyBillMemberIds,
  };
}

class ExpenseFirestoreMapper {
  static ExpenseModel fromMap(Map<String, dynamic> map, String id) =>
      ExpenseModel(
        id: id,
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        category: map['category'] ?? 'Other',
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        paidBy: map['paidBy'] ?? '',
        splitType: SplitType.values.firstWhere(
          (e) => e.name == map['splitType'],
          orElse: () => SplitType.equal,
        ),
        splitAmong: List<String>.from(map['splitAmong'] ?? []),
        createdBy: map['createdBy'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
        month: map['month'] ?? '',
        receiptUrl: map['receiptUrl'],
      );

  static Map<String, dynamic> toMap(ExpenseModel expense) => {
    'title': expense.title,
    'amount': expense.amount,
    'category': expense.category,
    'date': Timestamp.fromDate(expense.date),
    'paidBy': expense.paidBy,
    'splitType': expense.splitType.name,
    'splitAmong': expense.splitAmong,
    'createdBy': expense.createdBy,
    'createdAt': FieldValue.serverTimestamp(),
    'month': expense.month,
    if (expense.receiptUrl != null) 'receiptUrl': expense.receiptUrl,
  };

  static Map<String, dynamic> toUpdateMap(RoomExpenseUpdate changes) => {
    'title': changes.title,
    'amount': changes.amount,
    'category': changes.category,
    'date': Timestamp.fromDate(changes.date),
    'splitType': changes.splitType.name,
    'splitAmong': changes.splitAmong,
    'month': changes.month,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class BillFirestoreMapper {
  static Map<String, dynamic> toUpdateMap(RoomBillUpdate changes) => {
    'type': changes.type.name,
    'amount': changes.amount,
    'date': Timestamp.fromDate(changes.date),
    'month': changes.month,
  };

  static BillModel fromMap(Map<String, dynamic> map, String id) => BillModel(
    id: id,
    type: BillType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => BillType.rent,
    ),
    amount: (map['amount'] ?? 0).toDouble(),
    paidBy: map['paidBy'] ?? '',
    month: map['month'] ?? '',
    date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    receiptUrl: map['receiptUrl'],
    splitType: map['splitType'] ?? 'equal',
    splitAmong: List<String>.from(map['splitAmong'] ?? []),
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  static Map<String, dynamic> toMap(BillModel bill) => {
    'type': bill.type.name,
    'amount': bill.amount,
    'paidBy': bill.paidBy,
    'month': bill.month,
    'splitType': bill.splitType,
    'splitAmong': bill.splitAmong,
    'date': Timestamp.fromDate(bill.date),
    'receiptUrl': bill.receiptUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class ActivityFirestoreMapper {
  static ActivityModel fromMap(Map<String, dynamic> map, String id) =>
      ActivityModel(
        id: id,
        type: ActivityType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => ActivityType.expenseAdded,
        ),
        performedBy: map['performedBy'] ?? '',
        description: map['description'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        metadata: map['metadata'] as Map<String, dynamic>?,
      );

  static Map<String, dynamic> toMap(ActivityModel activity) => {
    'type': activity.type.name,
    'performedBy': activity.performedBy,
    'description': activity.description,
    'createdAt': FieldValue.serverTimestamp(),
    if (activity.metadata != null) 'metadata': activity.metadata,
  };
}
