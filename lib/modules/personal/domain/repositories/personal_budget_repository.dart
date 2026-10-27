import '../entities/budgets/personal_budget.dart';

abstract class PersonalBudgetRepository {
  Stream<List<PersonalBudget>> budgetsForMonth(String userId, String month);

  /// Update the existing category/month budget or add a new document.
  Future<void> save(String userId, PersonalBudget budget);
  Future<void> delete(String userId, String id);
}
