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

final projectDebtSummaryProvider = Provider.family<({double lent, double borrowed}), String>((ref, projectId) {
  final expenses = ref.watch(projectExpensesProvider(projectId)).valueOrNull ?? [];
  double lent = 0, borrowed = 0;
  for (final e in expenses.where((e) => e.hasDebt && !e.isSettled)) {
    if (e.debtType!.name == 'lent') lent += e.amount;
    else borrowed += e.amount;
  }
  return (lent: lent, borrowed: borrowed);
});

/// Returns a map of 'MMM yyyy' -> total spent, sorted chronologically
final projectMonthlySpendingProvider = Provider.family<Map<String, double>, String>((ref, projectId) {
  final expenses = ref.watch(projectExpensesProvider(projectId)).valueOrNull ?? [];
  final map = <String, double>{};
  for (final e in expenses) {
    final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
    map[key] = (map[key] ?? 0) + e.amount;
  }
  final sorted = Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  return sorted;
});

/// Payment method -> total amount
final projectPaymentBreakdownProvider = Provider.family<Map<String, double>, String>((ref, projectId) {
  final expenses = ref.watch(projectExpensesProvider(projectId)).valueOrNull ?? [];
  final map = <String, double>{};
  for (final e in expenses) {
    map[e.paymentMethod.name] = (map[e.paymentMethod.name] ?? 0) + e.amount;
  }
  return map;
});

/// Per-person unsettled debt: personName -> (lent, borrowed)
final projectPersonDebtsProvider = Provider.family<Map<String, ({double lent, double borrowed})>, String>((ref, projectId) {
  final expenses = ref.watch(projectExpensesProvider(projectId)).valueOrNull ?? [];
  final map = <String, ({double lent, double borrowed})>{};
  for (final e in expenses.where((e) => e.hasDebt && !e.isSettled && e.personName != null)) {
    final name = e.personName!;
    final cur = map[name] ?? (lent: 0.0, borrowed: 0.0);
    if (e.debtType == ProjectDebtType.lent) {
      map[name] = (lent: cur.lent + e.amount, borrowed: cur.borrowed);
    } else {
      map[name] = (lent: cur.lent, borrowed: cur.borrowed + e.amount);
    }
  }
  return map;
});
