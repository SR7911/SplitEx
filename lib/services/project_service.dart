import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/project_model.dart';

class ProjectService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _projectsRef(String uid) =>
      _db.collection('users').doc(uid).collection('projects');

  Future<ProjectModel> createProject({
    required String uid,
    required String name,
    String? description,
    required String projectType,
    required double estimatedBudget,
    required DateTime startDate,
    DateTime? targetEndDate,
  }) async {
    final doc = _projectsRef(uid).doc();
    final project = ProjectModel(
      id: doc.id,
      name: name,
      description: description,
      projectType: projectType,
      estimatedBudget: estimatedBudget,
      startDate: startDate,
      targetEndDate: targetEndDate,
      createdBy: uid,
      createdAt: DateTime.now(),
    );
    await doc.set(project.toMap());
    return project;
  }

  Future<void> updateStatus(String uid, String projectId, ProjectStatus status) async {
    await _projectsRef(uid).doc(projectId).update({'status': status.name});
  }

  Future<void> deleteProject(String uid, String projectId) async {
    await _projectsRef(uid).doc(projectId).delete();
  }

  Stream<List<ProjectModel>> getProjectsStream(String uid) {
    return _projectsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ProjectModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<ProjectModel?> getProjectStream(String uid, String projectId) {
    return _projectsRef(uid).doc(projectId).snapshots().map(
          (d) => d.exists ? ProjectModel.fromMap(d.data()!, d.id) : null,
        );
  }
}

class ProjectExpenseService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _expensesRef(String uid, String projectId) =>
      _db.collection('users').doc(uid).collection('projects').doc(projectId).collection('expenses');

  Future<ProjectExpenseModel> addExpense(String uid, ProjectExpenseModel expense) async {
    final doc = _expensesRef(uid, expense.projectId).doc();
    await doc.set(expense.toMap());
    return ProjectExpenseModel.fromMap(
        {...expense.toMap(), 'createdAt': Timestamp.now()}, doc.id);
  }

  Future<void> deleteExpense(String uid, String projectId, String expenseId) async {
    await _expensesRef(uid, projectId).doc(expenseId).delete();
  }

  Stream<List<ProjectExpenseModel>> getExpensesStream(String uid, String projectId) {
    return _expensesRef(uid, projectId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ProjectExpenseModel.fromMap(d.data(), d.id)).toList());
  }
}
