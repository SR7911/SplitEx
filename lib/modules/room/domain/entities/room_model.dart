
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

  bool isAdmin(String userId) => adminId == userId;
  bool isMember(String userId) => memberIds.contains(userId);
}
