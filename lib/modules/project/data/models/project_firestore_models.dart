import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/project/domain/entities/project_model.dart';
import 'package:split_ex/modules/project/domain/entities/project_update.dart';
import 'package:split_ex/modules/project/domain/entities/project_expense_update.dart';
import 'package:split_ex/modules/project/domain/entities/project_partial_settlement.dart';

class ProjectPartialSettlementFirestoreMapper {
  static ProjectPartialSettlement fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    DateTime? date;
    if (rawDate is String) date = DateTime.tryParse(rawDate);
    return ProjectPartialSettlement(
      amount: (map['amount'] ?? 0).toDouble(),
      date: date,
      note: map['note'] as String? ?? '',
    );
  }

  static Map<String, dynamic> toMap(ProjectPartialSettlement settlement) => {
    'amount': settlement.amount,
    'date': settlement.date?.toIso8601String(),
    'note': settlement.note,
  };
}

class ProjectFirestoreMapper {
  static ProjectModel fromMap(Map<String, dynamic> map, String id) =>
      ProjectModel(
        id: id,
        name: map['name'] ?? '',
        description: map['description'],
        projectType: map['projectType'] ?? 'Other',
        estimatedBudget: (map['estimatedBudget'] ?? 0).toDouble(),
        startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        targetEndDate: (map['targetEndDate'] as Timestamp?)?.toDate(),
        status: ProjectStatus.values.firstWhere(
          (value) => value.name == map['status'],
          orElse: () => ProjectStatus.active,
        ),
        createdBy: map['createdBy'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  static Map<String, dynamic> toMap(ProjectModel project) => {
    'name': project.name,
    'description': project.description,
    'projectType': project.projectType,
    'estimatedBudget': project.estimatedBudget,
    'startDate': Timestamp.fromDate(project.startDate),
    'targetEndDate': project.targetEndDate != null
        ? Timestamp.fromDate(project.targetEndDate!)
        : null,
    'status': project.status.name,
    'createdBy': project.createdBy,
    'createdAt': FieldValue.serverTimestamp(),
  };

  static Map<String, dynamic> toUpdateMap(ProjectUpdate changes) => {
    'name': changes.name,
    'description': changes.description,
    'projectType': changes.projectType,
    'estimatedBudget': changes.estimatedBudget,
    'startDate': Timestamp.fromDate(changes.startDate),
    'targetEndDate': changes.targetEndDate != null
        ? Timestamp.fromDate(changes.targetEndDate!)
        : null,
    'status': changes.status.name,
  };
}

class ProjectExpenseFirestoreMapper {
  static ProjectExpenseModel fromMap(Map<String, dynamic> map, String id) =>
      ProjectExpenseModel(
        id: id,
        projectId: map['projectId'] ?? '',
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        category: map['category'] ?? 'Other',
        vendor: map['vendor'],
        notes: map['notes'],
        paymentMethod: PaymentMethod.values.firstWhere(
          (value) => value.name == map['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        createdBy: map['createdBy'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        debtType: map['debtType'] != null
            ? ProjectDebtType.values.firstWhere(
                (value) => value.name == map['debtType'],
                orElse: () => ProjectDebtType.lent,
              )
            : null,
        personName: map['personName'],
        isSettled: map['isSettled'] ?? false,
        settledAmount: (map['settledAmount'] ?? 0).toDouble(),
        partialSettlements: (map['partialSettlements'] as List? ?? [])
            .map(
              (value) => ProjectPartialSettlementFirestoreMapper.fromMap(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
      );

  static Map<String, dynamic> toMap(ProjectExpenseModel expense) => {
    'projectId': expense.projectId,
    'title': expense.title,
    'amount': expense.amount,
    'category': expense.category,
    'vendor': expense.vendor,
    'notes': expense.notes,
    'paymentMethod': expense.paymentMethod.name,
    'date': Timestamp.fromDate(expense.date),
    'createdBy': expense.createdBy,
    'createdAt': FieldValue.serverTimestamp(),
    'debtType': expense.debtType?.name,
    'personName': expense.personName,
    'isSettled': expense.isSettled,
    'settledAmount': expense.settledAmount,
    'partialSettlements': expense.partialSettlements
        .map(ProjectPartialSettlementFirestoreMapper.toMap)
        .toList(),
  };

  static Map<String, dynamic> toUpdateMap(ProjectExpenseUpdate changes) => {
    'title': changes.title,
    'amount': changes.amount,
    'category': changes.category,
    'vendor': changes.vendor,
    'notes': changes.notes,
    'paymentMethod': changes.paymentMethod.name,
    'date': Timestamp.fromDate(changes.date),
    'debtType': changes.debtType?.name,
    'personName': changes.personName,
    'isSettled': changes.isSettled,
  };
}
