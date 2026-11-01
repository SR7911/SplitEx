import 'package:cloud_firestore/cloud_firestore.dart';

/// Owns the Room Firestore paths and membership writes shared by repositories.
class RoomFirestoreDataSource {
  final FirebaseFirestore db;
  RoomFirestoreDataSource({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get rooms => db.collection('rooms');
  CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  CollectionReference<Map<String, dynamic>> expenses(String roomId) =>
      rooms.doc(roomId).collection('expenses');
  CollectionReference<Map<String, dynamic>> bills(String roomId) =>
      rooms.doc(roomId).collection('bills');
  CollectionReference<Map<String, dynamic>> activities(String roomId) =>
      rooms.doc(roomId).collection('activities');
  CollectionReference<Map<String, dynamic>> settlements(String roomId) =>
      rooms.doc(roomId).collection('settlements');

  Future<void> createRoom(
    String roomId,
    Map<String, dynamic> data,
    String userId,
  ) async {
    final batch = db.batch();
    batch.set(rooms.doc(roomId), data);
    batch.set(users.doc(userId), {
      'rooms': FieldValue.arrayUnion([roomId]),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<(String, Map<String, dynamic>)?> joinRoom(
    String inviteCode,
    String userId, {
    required int maxMembers,
  }) async {
    final query = await rooms
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final ref = query.docs.first.reference;
    return db.runTransaction((transaction) async {
      final latest = await transaction.get(ref);
      final data = latest.data();
      if (data == null) return null;
      final memberIds = List<String>.from(data['memberIds'] ?? []);
      if (memberIds.contains(userId)) return (latest.id, data);
      if (memberIds.length >= maxMembers) {
        throw Exception('Room is full (max $maxMembers members)');
      }
      transaction.update(ref, {
        'memberIds': FieldValue.arrayUnion([userId]),
      });
      transaction.set(users.doc(userId), {
        'rooms': FieldValue.arrayUnion([latest.id]),
      }, SetOptions(merge: true));
      return (latest.id, data);
    });
  }

  Future<void> removeMember(String roomId, String userId) async {
    final userRef = users.doc(userId);
    final userExists = (await userRef.get()).exists;
    final batch = db.batch();
    batch.update(rooms.doc(roomId), {
      'memberIds': FieldValue.arrayRemove([userId]),
    });
    if (userExists) {
      batch.update(userRef, {
        'rooms': FieldValue.arrayRemove([roomId]),
      });
    }
    await batch.commit();
  }
}
