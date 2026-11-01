import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/project/data/datasources/project_firestore_data_source.dart';
import 'package:split_ex/modules/project/data/models/project_firestore_models.dart';
import 'package:split_ex/modules/project/domain/entities/project_model.dart';
import 'package:split_ex/modules/project/domain/entities/project_update.dart';
import 'package:split_ex/modules/project/domain/entities/project_expense_update.dart';
import 'package:split_ex/modules/project/domain/repositories/project_repository.dart';
import 'package:split_ex/modules/project/domain/repositories/project_expense_repository.dart';

class FirestoreProjectRepository implements ProjectRepository {
  final ProjectFirestoreDataSource _source;
  FirestoreProjectRepository({
    FirebaseFirestore? firestore,
    ProjectFirestoreDataSource? source,
  }) : _source =
           source ??
           ProjectFirestoreDataSource(firestore ?? FirebaseFirestore.instance);

  @override
  Future<ProjectModel> createProject({
    required String uid,
    required String name,
    String? description,
    required String projectType,
    required double estimatedBudget,
    required DateTime startDate,
    DateTime? targetEndDate,
  }) async {
    final project = ProjectModel(
      id: '',
      name: name,
      description: description,
      projectType: projectType,
      estimatedBudget: estimatedBudget,
      startDate: startDate,
      targetEndDate: targetEndDate,
      createdBy: uid,
      createdAt: DateTime.now(),
    );
    final (id, data) = await _source.createProject(
      uid,
      ProjectFirestoreMapper.toMap(project),
    );
    return ProjectFirestoreMapper.fromMap(data, id);
  }

  @override
  Future<void> updateProject(
    String uid,
    String projectId,
    ProjectUpdate changes,
  ) => _source.updateProject(
    uid,
    projectId,
    ProjectFirestoreMapper.toUpdateMap(changes),
  );
  @override
  Future<void> updateStatus(
    String uid,
    String projectId,
    ProjectStatus status,
  ) => _source.updateProject(uid, projectId, {'status': status.name});
  @override
  Future<void> deleteProject(String uid, String projectId) =>
      _source.deleteProject(uid, projectId);
  @override
  Stream<List<ProjectModel>> getProjectsStream(String uid) => _source
      .watchProjects(uid)
      .map(
        (documents) => documents
            .map(
              (document) =>
                  ProjectFirestoreMapper.fromMap(document.$2, document.$1),
            )
            .toList(),
      );
  @override
  Stream<ProjectModel?> getProjectStream(String uid, String projectId) =>
      _source
          .watchProject(uid, projectId)
          .map(
            (data) => data == null
                ? null
                : ProjectFirestoreMapper.fromMap(data, projectId),
          );
}

class FirestoreProjectExpenseRepository implements ProjectExpenseRepository {
  final ProjectFirestoreDataSource _source;
  FirestoreProjectExpenseRepository({
    FirebaseFirestore? firestore,
    ProjectFirestoreDataSource? source,
  }) : _source =
           source ??
           ProjectFirestoreDataSource(firestore ?? FirebaseFirestore.instance);

  @override
  Future<ProjectExpenseModel> addExpense(
    String uid,
    ProjectExpenseModel expense,
  ) async {
    final (id, data) = await _source.addExpense(
      uid,
      expense.projectId,
      ProjectExpenseFirestoreMapper.toMap(expense),
    );
    return ProjectExpenseFirestoreMapper.fromMap(data, id);
  }

  @override
  Future<void> updateExpense(
    String uid,
    String projectId,
    String expenseId,
    ProjectExpenseUpdate changes,
  ) => _source.updateExpense(
    uid,
    projectId,
    expenseId,
    ProjectExpenseFirestoreMapper.toUpdateMap(changes),
  );
  @override
  Future<void> markExpenseSettled(
    String uid,
    String projectId,
    String expenseId,
  ) => _source.updateExpense(uid, projectId, expenseId, {'isSettled': true});
  @override
  Future<void> deleteExpense(String uid, String projectId, String expenseId) =>
      _source.deleteExpense(uid, projectId, expenseId);
  @override
  Future<void> settleExpense(String uid, String projectId, String expenseId) =>
      _source.appendPayment(uid, projectId, expenseId);
  @override
  Future<void> partialSettleExpense(
    String uid,
    String projectId,
    String expenseId,
    double partialAmount,
    String? note,
  ) => _source.appendPayment(
    uid,
    projectId,
    expenseId,
    partialAmount: partialAmount,
    note: note,
  );
  @override
  Stream<List<ProjectExpenseModel>> getExpensesStream(
    String uid,
    String projectId,
  ) => _source
      .watchExpenses(uid, projectId)
      .map(
        (documents) => documents
            .map(
              (document) => ProjectExpenseFirestoreMapper.fromMap(
                document.$2,
                document.$1,
              ),
            )
            .toList(),
      );
}
