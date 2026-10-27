import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/budgets/personal_budget.dart';
import 'package:split_ex/modules/personal/domain/use_cases/budgets/save_personal_budget.dart';

final personalMonthBudgetsProvider =
    StreamProvider.family<List<PersonalBudget>, String>((ref, month) {
      final userId = ref.watch(personalUserIdProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);
      return ref
          .watch(personalBudgetRepositoryProvider)
          .budgetsForMonth(userId, month);
    });

final savePersonalBudgetProvider = Provider<SavePersonalBudget>(
  (ref) => SavePersonalBudget(ref.watch(personalBudgetRepositoryProvider)),
);
