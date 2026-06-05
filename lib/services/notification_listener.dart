import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/services/notification_service.dart';

/// Listens to Firestore for new unread notifications and shows local notification.
class NotificationListener {
  final NotificationService _notificationService;
  final String userId;
  StreamSubscription? _subscription;
  final Set<String> _shownIds = {};

  NotificationListener({
    required NotificationService notificationService,
    required this.userId,
  }) : _notificationService = notificationService;

  void startListening() {
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final id = change.doc.id;
          if (_shownIds.contains(id)) continue;
          _shownIds.add(id);

          final data = change.doc.data();
          if (data != null) {
            _notificationService.showLocal(
              data['title'] ?? 'SplitEx',
              data['body'] ?? 'New notification',
            );
          }
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
