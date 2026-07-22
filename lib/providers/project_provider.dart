import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/project_service.dart';

final projectServiceProvider = Provider<ProjectService>((ref) => ProjectService());
final projectExpenseServiceProvider = Provider<ProjectExpenseService>((ref) => ProjectExpenseService());

final userProjectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(projectServiceProvider).getProjectsStream(uid);
});

final projectStreamProvider = StreamProvider.family<ProjectModel?, String>((ref, projectId) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(projectServiceProvider).getProjectStream(uid, projectId);
});

final projectExpensesProvider = StreamProvider.family<List<ProjectExpenseModel>, String>((ref, projectId) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(projectExpenseServiceProvider).getExpensesStream(uid, projectId);
});

final projectTotalSpentProvider = Provider.family<double, String>((ref, projectId) {
  final expenses = ref.watch(projectExpensesProvider(projectId)).valueOrNull ?? [];
  return expenses.fold(0.0, (sum, e) => sum + e.amount);
});

final projectCategoryBreakdownProvider = Provider.family<Map<String, double>, String>((ref, projectId) {
  final expenses = ref.watch(projectExpensesProvider(projectId)).valueOrNull ?? [];
  final map = <String, double>{};
  for (final e in expenses) {
    map[e.category] = (map[e.category] ?? 0) + e.amount;
  }
  return map;
});
