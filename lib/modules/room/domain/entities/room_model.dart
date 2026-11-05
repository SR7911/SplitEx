class RoomModel {
  final String id;
  final String name;
  final String inviteCode;
  final String adminId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String currentMonth;
  final bool isLocked;

  /// Durable access to the ledger, including people who have moved out.
  final List<String> participantIds;
  final List<String>? legacyBillMemberIds;
  final bool isArchived;

  const RoomModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.adminId,
    required this.memberIds,
    required this.createdAt,
    required this.currentMonth,
    this.isLocked = false,
    this.participantIds = const [],
    this.legacyBillMemberIds,
    this.isArchived = false,
  });

  bool isAdmin(String userId) => adminId == userId;
  bool isMember(String userId) => memberIds.contains(userId);
  List<String> get historicalMemberIds =>
      {...participantIds, ...memberIds}.toList();
  List<String> get billFallbackMemberIds => legacyBillMemberIds ?? memberIds;
  bool canRead(String userId) => historicalMemberIds.contains(userId);
  bool canWrite(String userId) => isMember(userId) && !isArchived && !isLocked;
}
