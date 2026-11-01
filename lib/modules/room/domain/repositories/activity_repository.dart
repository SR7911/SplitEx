import '../entities/activity_model.dart';

abstract interface class ActivityRepository {
  Future<void> log({
    required String roomId,
    required ActivityType type,
    required String performedBy,
    required String description,
    Map<String, dynamic>? metadata,
  });
  Stream<List<ActivityModel>> getActivitiesStream(String roomId);
}
