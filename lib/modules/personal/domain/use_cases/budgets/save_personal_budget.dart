import '../../entities/budgets/personal_budget.dart';
import '../../repositories/personal_budget_repository.dart';

class SavePersonalBudget {
  final PersonalBudgetRepository _repository;
  const SavePersonalBudget(this._repository);

  Future<void> call(String userId, PersonalBudget budget) async {
    if (!budget.budget.isFinite || budget.budget <= 0) {
      throw StateError('Enter a valid positive budget amount.');
    }
    if (budget.category.trim().isEmpty || budget.month.trim().isEmpty) {
      throw StateError('Choose a category and month.');
    }
    await _repository.save(userId, budget);
  }
}
