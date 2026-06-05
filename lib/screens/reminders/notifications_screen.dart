import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/notification_model.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationServiceProvider)
                .markAllAsRead(userId),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _NotificationTile(notification: n);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.expenseAdded:
        return Icons.add_circle;
      case NotificationType.expenseDeleted:
        return Icons.remove_circle;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.settlement:
        return Icons.check_circle;
      case NotificationType.memberJoined:
        return Icons.person_add;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(_icon, color: notification.isRead ? Colors.grey : Theme.of(context).colorScheme.primary),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notification.body),
      trailing: Text(
        DateFormat('dd/MM HH:mm').format(notification.createdAt),
        style: const TextStyle(fontSize: 11),
      ),
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationServiceProvider).markAsRead(notification.id);
        }
      },
    );
  }
}
