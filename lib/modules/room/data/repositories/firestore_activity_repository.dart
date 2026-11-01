import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/domain/repositories/activity_repository.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';

class FirestoreActivityRepository implements ActivityRepository {
  final RoomFirestoreDataSource _source;
  FirestoreActivityRepository({RoomFirestoreDataSource? source})
    : _source = source ?? RoomFirestoreDataSource();

  CollectionReference<Map<String, dynamic>> _ref(String roomId) {
    return _source.activities(roomId);
  }

  Future<void> log({
    required String roomId,
    required ActivityType type,
    required String performedBy,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    await _ref(roomId).add({
      'type': type.name,
      'performedBy': performedBy,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    });
  }

  Stream<List<ActivityModel>> getActivitiesStream(String roomId) {
    return _ref(roomId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ActivityFirestoreMapper.fromMap(d.data(), d.id))
              .toList(),
        );
  }
}
