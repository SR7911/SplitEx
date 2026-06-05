import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/activity_model.dart';

class ActivityService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String roomId) {
    return _firestore.collection('rooms').doc(roomId).collection('activities');
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
        .map((snap) => snap.docs
            .map((d) => ActivityModel.fromMap(d.data(), d.id))
            .toList());
  }
}
