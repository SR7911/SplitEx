/// A category spending limit for one calendar month.
class PersonalBudget {
  final String id;
  final String category;
  final double budget;
  final String userId;
  final String month;

  const PersonalBudget({
    required this.id,
    required this.category,
    required this.budget,
    required this.userId,
    required this.month,
  });
}
