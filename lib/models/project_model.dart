import 'package:cloud_firestore/cloud_firestore.dart';

enum ProjectStatus { active, completed, paused }
enum PaymentMethod { cash, upi, card, bankTransfer }

class ProjectModel {
  final String id;
  final String name;
  final String? description;
  final String projectType;
  final double estimatedBudget;
  final DateTime startDate;
  final DateTime? targetEndDate;
  final ProjectStatus status;
  final String createdBy;
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.projectType,
    required this.estimatedBudget,
    required this.startDate,
    this.targetEndDate,
    this.status = ProjectStatus.active,
    required this.createdBy,
    required this.createdAt,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map, String id) {
    return ProjectModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      projectType: map['projectType'] ?? 'Other',
      estimatedBudget: (map['estimatedBudget'] ?? 0).toDouble(),
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetEndDate: (map['targetEndDate'] as Timestamp?)?.toDate(),
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProjectStatus.active,
      ),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'projectType': projectType,
        'estimatedBudget': estimatedBudget,
        'startDate': Timestamp.fromDate(startDate),
        'targetEndDate': targetEndDate != null ? Timestamp.fromDate(targetEndDate!) : null,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };

  ProjectModel copyWith({String? name, String? description, String? projectType, double? estimatedBudget, DateTime? startDate, DateTime? targetEndDate, ProjectStatus? status}) => ProjectModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        projectType: projectType ?? this.projectType,
        estimatedBudget: estimatedBudget ?? this.estimatedBudget,
        startDate: startDate ?? this.startDate,
        targetEndDate: targetEndDate ?? this.targetEndDate,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

enum ProjectDebtType { lent, borrowed }

class ProjectExpenseModel {
  final String id;
  final String projectId;
  final String title;
  final double amount;
  final String category;
  final String? vendor;
  final String? notes;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final String createdBy;
  final DateTime createdAt;
  final ProjectDebtType? debtType;
  final String? personName;
  final bool isSettled;
  final double settledAmount;
  final List<Map<String, dynamic>> partialSettlements;

  const ProjectExpenseModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.amount,
    required this.category,
    this.vendor,
    this.notes,
    this.paymentMethod = PaymentMethod.cash,
    required this.date,
    required this.createdBy,
    required this.createdAt,
    this.debtType,
    this.personName,
    this.isSettled = false,
    this.settledAmount = 0,
    this.partialSettlements = const [],
  });

  bool get hasDebt => debtType != null;
  double get remainingAmount => amount - settledAmount;

  factory ProjectExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ProjectExpenseModel(
      id: id,
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      vendor: map['vendor'],
      notes: map['notes'],
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      debtType: map['debtType'] != null
          ? ProjectDebtType.values.firstWhere((e) => e.name == map['debtType'], orElse: () => ProjectDebtType.lent)
          : null,
      personName: map['personName'],
      isSettled: map['isSettled'] ?? false,
      settledAmount: (map['settledAmount'] ?? 0).toDouble(),
      partialSettlements: List<Map<String, dynamic>>.from(map['partialSettlements'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'title': title,
        'amount': amount,
        'category': category,
        'vendor': vendor,
        'notes': notes,
        'paymentMethod': paymentMethod.name,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'debtType': debtType?.name,
        'personName': personName,
        'isSettled': isSettled,
        'settledAmount': settledAmount,
        'partialSettlements': partialSettlements,
      };

  ProjectExpenseModel copyWith({
    String? title,
    double? amount,
    String? category,
    String? vendor,
    String? notes,
    PaymentMethod? paymentMethod,
    DateTime? date,
    ProjectDebtType? debtType,
    String? personName,
    bool? isSettled,
    double? settledAmount,
    List<Map<String, dynamic>>? partialSettlements,
    bool clearDebt = false,
  }) =>
      ProjectExpenseModel(
        id: id,
        projectId: projectId,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        vendor: vendor ?? this.vendor,
        notes: notes ?? this.notes,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        date: date ?? this.date,
        createdBy: createdBy,
        createdAt: createdAt,
        debtType: clearDebt ? null : (debtType ?? this.debtType),
        personName: clearDebt ? null : (personName ?? this.personName),
        isSettled: isSettled ?? this.isSettled,
        settledAmount: settledAmount ?? this.settledAmount,
        partialSettlements: partialSettlements ?? this.partialSettlements,
      );
}
