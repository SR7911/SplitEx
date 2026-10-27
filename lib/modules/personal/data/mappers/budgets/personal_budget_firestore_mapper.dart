import '../../../domain/entities/budgets/personal_budget.dart';

class PersonalBudgetFirestoreMapper {
  static PersonalBudget fromMap(Map<String, dynamic> map, String id) =>
      PersonalBudget(
        id: id,
        category: map['category'] ?? '',
        budget: (map['budget'] ?? 0).toDouble(),
        userId: map['userId'] ?? '',
        month: map['month'] ?? '',
      );

  static Map<String, dynamic> toMap(PersonalBudget budget) => {
    'category': budget.category,
    'budget': budget.budget,
    'userId': budget.userId,
    'month': budget.month,
  };
}
