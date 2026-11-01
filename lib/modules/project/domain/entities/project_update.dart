import 'project_model.dart';

class ProjectUpdate {
  final String name;
  final String? description;
  final String projectType;
  final double estimatedBudget;
  final DateTime startDate;
  final DateTime? targetEndDate;
  final ProjectStatus status;

  const ProjectUpdate({
    required this.name,
    this.description,
    required this.projectType,
    required this.estimatedBudget,
    required this.startDate,
    this.targetEndDate,
    required this.status,
  });
}
