import '../entities/savings/savings_goal.dart';

abstract class SavingsGoalRepository {
  Stream<List<SavingsGoal>> watch(String uid);
  Stream<List<SavingsEntry>> entries(String uid, String goalId);
  Future<void> save(String uid, SavingsGoal goal);
  Future<void> archive(String uid, String id, bool archived);
  Future<void> record(String uid, String goalId, SavingsEntry entry);
  Future<void> removeEntry(String uid, String goalId, String entryId);
}
