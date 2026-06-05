import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String name;
  final String inviteCode;
  final String adminId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String currentMonth;
  final bool isLocked;

  const RoomModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.adminId,
    required this.memberIds,
    required this.createdAt,
    required this.currentMonth,
    this.isLocked = false,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map, String id) {
    return RoomModel(
      id: id,
      name: map['name'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      adminId: map['adminId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentMonth: map['currentMonth'] ?? '',
      isLocked: map['isLocked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'adminId': adminId,
      'memberIds': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
      'currentMonth': currentMonth,
      'isLocked': isLocked,
    };
  }

  bool isAdmin(String userId) => adminId == userId;
  bool isMember(String userId) => memberIds.contains(userId);
}
