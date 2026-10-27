import '../entities/recurring/personal_recurring_edit.dart';
import '../entities/recurring/personal_recurring_entry.dart';

abstract class PersonalRecurringRepository {
  Stream<List<PersonalRecurringEntry>> entries(String userId);
  Future<void> add(String userId, PersonalRecurringEntry entry);
  Future<void> update(
    String userId,
    PersonalRecurringEntry current,
    PersonalRecurringChanges changes,
  );
  Future<void> toggle(String userId, String id, bool active);
  Future<void> delete(String userId, String id);
}
