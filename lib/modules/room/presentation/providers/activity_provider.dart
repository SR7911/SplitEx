import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/modules/room/dependencies.dart';
export 'package:split_ex/modules/room/dependencies.dart' show activityServiceProvider;

final activitiesStreamProvider =
    StreamProvider.family<List<ActivityModel>, String>((ref, roomId) {
  return ref.watch(activityServiceProvider).getActivitiesStream(roomId);
});

/// Recent activities across all user rooms (last 5, current month only)
final recentActivitiesProvider =
    Provider<List<ActivityModel>>((ref) {
  final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final all = <ActivityModel>[];
  for (final room in rooms) {
    final activities =
        ref.watch(activitiesStreamProvider(room.id)).valueOrNull ?? [];
    all.addAll(activities.where(
      (a) => a.createdAt.year == now.year && a.createdAt.month == now.month,
    ));
  }
  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all.take(5).toList();
});
