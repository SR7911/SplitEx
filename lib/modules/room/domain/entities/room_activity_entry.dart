import 'activity_model.dart';

class RoomActivityEntry {
  final ActivityType type;
  final String performedBy;
  final String description;
  final Map<String, dynamic>? metadata;

  const RoomActivityEntry({
    required this.type,
    required this.performedBy,
    required this.description,
    this.metadata,
  });
}
