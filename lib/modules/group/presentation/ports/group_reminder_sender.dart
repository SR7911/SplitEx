abstract interface class GroupReminderSender {
  Future<void> sendReminder({
    required String groupId,
    required String fromName,
    required String targetUserId,
    required double amount,
  });
}
