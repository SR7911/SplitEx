import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/activity_service.dart';

final activityServiceProvider =
    Provider<ActivityService>((ref) => ActivityService());

final activitiesStreamProvider =
    StreamProvider.family<List<ActivityModel>, String>((ref, roomId) {
  return ref.watch(activityServiceProvider).getActivitiesStream(roomId);
});

/// Recent activities across all user rooms (last 5)
final recentActivitiesProvider =
    Provider<List<ActivityModel>>((ref) {
  final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
  final all = <ActivityModel>[];
  for (final room in rooms) {
    final activities =
        ref.watch(activitiesStreamProvider(room.id)).valueOrNull ?? [];
    all.addAll(activities);
  }
  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all.take(5).toList();
});
