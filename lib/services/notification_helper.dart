import 'package:split_ex/models/notification_model.dart';
import 'package:split_ex/services/notification_service.dart';

class NotificationHelper {
  final NotificationService _service;

  NotificationHelper(this._service);

  Future<void> onExpenseAdded({
    required String roomId,
    required String payerName,
    required String title,
    required double amount,
    required List<String> memberIds,
    required String excludeUserId,
  }) async {
    final targets = memberIds.where((id) => id != excludeUserId).toList();
    if (targets.isEmpty) return;
    await _service.notify(
      roomId: roomId,
      targetUserIds: targets,
      title: 'New Expense',
      body: '$payerName added "$title" for ₹${amount.toStringAsFixed(0)}',
      type: NotificationType.expenseAdded,
    );
  }

  Future<void> onExpenseDeleted({
    required String roomId,
    required String adminName,
    required String title,
    required List<String> memberIds,
    required String excludeUserId,
  }) async {
    final targets = memberIds.where((id) => id != excludeUserId).toList();
    if (targets.isEmpty) return;
    await _service.notify(
      roomId: roomId,
      targetUserIds: targets,
      title: 'Expense Deleted',
      body: '$adminName deleted "$title"',
      type: NotificationType.expenseDeleted,
    );
  }

  Future<void> onMemberJoined({
    required String roomId,
    required String memberName,
    required List<String> memberIds,
    required String excludeUserId,
  }) async {
    final targets = memberIds.where((id) => id != excludeUserId).toList();
    if (targets.isEmpty) return;
    await _service.notify(
      roomId: roomId,
      targetUserIds: targets,
      title: 'New Member',
      body: '$memberName joined the room',
      type: NotificationType.memberJoined,
    );
  }

  Future<void> sendReminder({
    required String roomId,
    required String fromName,
    required String targetUserId,
    required double amount,
  }) async {
    await _service.notify(
      roomId: roomId,
      targetUserIds: [targetUserId],
      title: 'Payment Reminder',
      body: '$fromName reminded you to pay ₹${amount.toStringAsFixed(0)}',
      type: NotificationType.reminder,
    );
    await _service.showLocal(
      'Reminder Sent',
      'Reminder sent for ₹${amount.toStringAsFixed(0)}',
    );
  }
}
