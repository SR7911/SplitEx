import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:split_ex/models/notification_model.dart';

class NotificationService {
  final _firestore = FirebaseFirestore.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  CollectionReference get _collection => _firestore.collection('notifications');

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);
  }

  /// Send notification to specific users in a room.
  Future<void> notify({
    required String roomId,
    required List<String> targetUserIds,
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    final batch = _firestore.batch();
    for (final uid in targetUserIds) {
      final doc = _collection.doc();
      batch.set(doc, {
        'roomId': roomId,
        'targetUserId': uid,
        'title': title,
        'body': body,
        'type': type.name,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Show local notification on device.
  Future<void> showLocal(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'splitex_channel',
        'SplitEx Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Stream of notifications for a user, ordered by most recent.
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _collection
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                NotificationModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Mark single notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _collection.doc(notificationId).update({'isRead': true});
  }

  /// Mark all as read for user.
  Future<void> markAllAsRead(String userId) async {
    final snap = await _collection
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Get unread count stream.
  Stream<int> unreadCountStream(String userId) {
    return _collection
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
