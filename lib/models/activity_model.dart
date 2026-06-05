import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  expenseAdded,
  expenseEdited,
  expenseDeleted,
  settlementCreated,
  settlementConfirmed,
  memberJoined,
  memberLeft,
  roomCreated,
  roomSettingsChanged,
}

class ActivityModel {
  final String id;
  final ActivityType type;
  final String performedBy;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const ActivityModel({
    required this.id,
    required this.type,
    required this.performedBy,
    required this.description,
    required this.createdAt,
    this.metadata,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityModel(
      id: id,
      type: ActivityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityType.expenseAdded,
      ),
      performedBy: map['performedBy'] ?? '',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'performedBy': performedBy,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}
