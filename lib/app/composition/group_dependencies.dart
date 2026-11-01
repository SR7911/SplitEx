import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/group/dependencies.dart';
import 'package:split_ex/modules/group/data/repositories/firestore_group_repositories.dart';
import 'package:split_ex/modules/group/presentation/ports/group_reminder_sender.dart';
import 'package:split_ex/modules/group/presentation/ports/group_payee_lookup.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:split_ex/modules/notifications/services/notification_helper.dart';
import 'package:split_ex/app/auth/services/user_service.dart';

class _GroupReminderAdapter implements GroupReminderSender {
  final NotificationHelper helper;
  _GroupReminderAdapter(this.helper);

  @override
  Future<void> sendReminder({
    required String groupId,
    required String fromName,
    required String targetUserId,
    required double amount,
  }) => helper.sendReminder(
    roomId: groupId,
    fromName: fromName,
    targetUserId: targetUserId,
    amount: amount,
  );
}

class _GroupPayeeAdapter implements GroupPayeeLookup {
  final UserService users;
  _GroupPayeeAdapter(this.users);

  @override
  Future<String?> upiIdFor(String userId) async =>
      (await users.getUserProfile(userId))?.upiId;
}

List<Override> groupDependencyOverrides() => [
  groupServiceProvider.overrideWith(
    (ref) => FirestoreGroupRepository(firestore: FirebaseFirestore.instance),
  ),
  groupFirestoreExpenseRepositoryProvider.overrideWith(
    (ref) =>
        FirestoreGroupExpenseRepository(firestore: FirebaseFirestore.instance),
  ),
  groupFirestoreSettlementRepositoryProvider.overrideWith(
    (ref) => FirestoreGroupSettlementRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
  groupReminderSenderProvider.overrideWith(
    (ref) => _GroupReminderAdapter(
      NotificationHelper(ref.watch(notificationServiceProvider)),
    ),
  ),
  groupPayeeLookupProvider.overrideWith(
    (ref) => _GroupPayeeAdapter(UserService()),
  ),
];
