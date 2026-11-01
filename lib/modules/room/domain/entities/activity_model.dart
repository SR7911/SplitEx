
enum ActivityType {
  expenseAdded,
  expenseEdited,
  expenseDeleted,
  billAdded,
  billEdited,
  billDeleted,
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

}
