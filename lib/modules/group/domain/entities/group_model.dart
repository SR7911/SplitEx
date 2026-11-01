enum GroupStatus { active, archived }

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final String currency;
  final String inviteCode;
  final String createdBy;
  final List<String> memberIds;
  final GroupStatus status;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    this.endDate,
    this.currency = '₹',
    required this.inviteCode,
    required this.createdBy,
    required this.memberIds,
    this.status = GroupStatus.active,
    required this.createdAt,
  });

  bool get isArchived => status == GroupStatus.archived;
  bool isMember(String uid) => memberIds.contains(uid);
  bool isAdmin(String uid) => createdBy == uid;

  GroupModel copyWith({GroupStatus? status, List<String>? memberIds}) {
    return GroupModel(
      id: id,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      inviteCode: inviteCode,
      createdBy: createdBy,
      memberIds: memberIds ?? this.memberIds,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
