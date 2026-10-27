import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      currency: map['currency'] ?? '₹',
      inviteCode: map['inviteCode'] ?? '',
      createdBy: map['createdBy'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      status: GroupStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => GroupStatus.active,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'currency': currency,
        'inviteCode': inviteCode,
        'createdBy': createdBy,
        'memberIds': memberIds,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

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
