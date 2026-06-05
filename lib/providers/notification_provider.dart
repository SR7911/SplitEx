import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/notification_model.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/notification_service.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final notificationsStreamProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(notificationServiceProvider).getNotificationsStream(userId);
});

final unreadCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(notificationServiceProvider).unreadCountStream(userId);
});
