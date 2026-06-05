import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { expenseAdded, expenseDeleted, reminder, settlement, memberJoined }

class NotificationModel {
  final String id;
  final String roomId;
  final String targetUserId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.roomId,
    required this.targetUserId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      roomId: map['roomId'] ?? '',
      targetUserId: map['targetUserId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.expenseAdded,
      ),
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'targetUserId': targetUserId,
      'title': title,
      'body': body,
      'type': type.name,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
