import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/notifications/models/notification_model.dart';
import 'package:split_ex/modules/notifications/services/notification_service.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';

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
