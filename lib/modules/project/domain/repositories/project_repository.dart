import '../entities/project_model.dart';
import '../entities/project_update.dart';

abstract interface class ProjectRepository {
  Future<ProjectModel> createProject({
    required String uid,
    required String name,
    String? description,
    required String projectType,
    required double estimatedBudget,
    required DateTime startDate,
    DateTime? targetEndDate,
  });
  Future<void> updateProject(
    String uid,
    String projectId,
    ProjectUpdate changes,
  );
  Future<void> updateStatus(String uid, String projectId, ProjectStatus status);
  Future<void> deleteProject(String uid, String projectId);
  Stream<List<ProjectModel>> getProjectsStream(String uid);
  Stream<ProjectModel?> getProjectStream(String uid, String projectId);
}
