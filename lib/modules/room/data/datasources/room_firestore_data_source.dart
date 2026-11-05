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

  /// Keeps legacy repository entry points under the same archive/version guard.
  Future<void> writeOpenLedger(
    String roomId,
    Future<void> Function(Transaction) write,
  ) async {
    await db.runTransaction((transaction) async {
      final ref = rooms.doc(roomId);
      final room = (await transaction.get(ref)).data();
      if (room == null ||
          room['isArchived'] == true ||
          room['isLocked'] == true) {
        throw Exception('This room is read-only.');
      }
      await write(transaction);
      transaction.update(ref, {'ledgerVersion': FieldValue.increment(1)});
    });
  }

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
        .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final ref = query.docs.first.reference;
    return db.runTransaction((transaction) async {
      final latest = await transaction.get(ref);
      final data = latest.data();
      if (data == null) return null;
      final memberIds = List<String>.from(data['memberIds'] ?? []);
      if (data['isArchived'] == true || data['isLocked'] == true) {
        throw Exception('This room is closed to new members.');
      }
      if (memberIds.contains(userId)) return (latest.id, data);
      if (memberIds.length >= maxMembers) {
        throw Exception('Room is full (max $maxMembers members)');
      }
      final updated = {
        ...data,
        'memberIds': [...memberIds, userId],
        'participantIds': {
          ...List<String>.from(data['participantIds'] ?? []),
          ...memberIds,
          userId,
        }.toList(),
        'legacyBillMemberIds': data['legacyBillMemberIds'] ?? memberIds,
      };
      transaction.update(ref, {
        'memberIds': updated['memberIds'],
        'participantIds': updated['participantIds'],
        'legacyBillMemberIds': updated['legacyBillMemberIds'],
        'ledgerVersion': FieldValue.increment(1),
      });
      transaction.set(users.doc(userId), {
        'rooms': FieldValue.arrayUnion([latest.id]),
      }, SetOptions(merge: true));
      _activity(
        transaction,
        latest.id,
        userId,
        'memberJoined',
        'A member joined the room',
        {'memberId': userId},
      );
      return (latest.id, updated);
    });
  }

  Future<void> removeMember(
    String roomId,
    String userId, {
    required String performedBy,
  }) async {
    await db.runTransaction((transaction) async {
      final roomRef = rooms.doc(roomId);
      final data = (await transaction.get(roomRef)).data();
      if (data == null) throw Exception('Room not found.');
      final members = List<String>.from(data['memberIds'] ?? []);
      if (!members.contains(performedBy) ||
          (performedBy != userId && data['adminId'] != performedBy)) {
        throw Exception('Only the admin can remove another member.');
      }
      if (!members.contains(userId)) return;
      if (data['adminId'] == userId && members.length > 1) {
        throw Exception('Transfer admin responsibility before leaving.');
      }
      final userRef = users.doc(userId);
      final user = await transaction.get(userRef);
      final remaining = members.where((id) => id != userId).toList();
      transaction.update(roomRef, {
        'memberIds': remaining,
        'participantIds': {
          ...List<String>.from(data['participantIds'] ?? []),
          ...members,
        }.toList(),
        'legacyBillMemberIds': data['legacyBillMemberIds'] ?? members,
        'ledgerVersion': FieldValue.increment(1),
        if (remaining.isEmpty) ...{
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedBy': performedBy,
        },
      });
      if (user.exists) {
        transaction.update(userRef, {
          'rooms': FieldValue.arrayRemove([roomId]),
        });
      }
      _activity(
        transaction,
        roomId,
        performedBy,
        'memberLeft',
        remaining.isEmpty
            ? 'Last member left; room archived'
            : 'A member left the room',
        {'memberId': userId},
      );
    });
  }

  Future<void> transferAdmin(
    String roomId,
    String adminId,
    String newAdminId,
  ) async {
    await db.runTransaction((transaction) async {
      final ref = rooms.doc(roomId);
      final data = (await transaction.get(ref)).data();
      if (data == null) throw Exception('Room not found.');
      final members = List<String>.from(data['memberIds'] ?? []);
      if (data['adminId'] != adminId || !members.contains(adminId)) {
        throw Exception('Only the current admin can transfer responsibility.');
      }
      if (data['isArchived'] == true)
        throw Exception('Restore the room first.');
      if (newAdminId == adminId || !members.contains(newAdminId)) {
        throw Exception('Choose another active member as admin.');
      }
      transaction.update(ref, {
        'adminId': newAdminId,
        'ledgerVersion': FieldValue.increment(1),
      });
      _activity(
        transaction,
        roomId,
        adminId,
        'roomSettingsChanged',
        'Admin responsibility transferred',
        {'previousAdminId': adminId, 'adminId': newAdminId},
      );
    });
  }

  Future<void> setArchived(String roomId, String userId, bool archived) async {
    await db.runTransaction((transaction) async {
      final ref = rooms.doc(roomId);
      final data = (await transaction.get(ref)).data();
      if (data == null || data['adminId'] != userId) {
        throw Exception('Only the room admin can archive or restore the room.');
      }
      final members = List<String>.from(data['memberIds'] ?? []);
      if (archived && !members.contains(userId))
        throw Exception('You are no longer an active member.');
      final rejoin = !archived && members.isEmpty;
      transaction.update(ref, {
        'isArchived': archived,
        'archivedAt': archived ? FieldValue.serverTimestamp() : null,
        'archivedBy': archived ? userId : null,
        'participantIds': {
          ...List<String>.from(data['participantIds'] ?? []),
          ...members,
          userId,
        }.toList(),
        if (rejoin) 'memberIds': [userId],
        'ledgerVersion': FieldValue.increment(1),
      });
      if (rejoin) {
        transaction.set(users.doc(userId), {
          'rooms': FieldValue.arrayUnion([roomId]),
        }, SetOptions(merge: true));
      }
      _activity(
        transaction,
        roomId,
        userId,
        'roomSettingsChanged',
        archived ? 'Room archived; history preserved' : 'Room restored',
        null,
      );
    });
  }

  /// Repairs durable access for members removed by older app versions. The
  /// original participant IDs remain recoverable from ledger snapshots.
  Future<void> restoreHistoricalParticipants(
    String roomId,
    String userId,
  ) async {
    final collections = await Future.wait([
      expenses(roomId).get(),
      bills(roomId).get(),
      settlements(roomId).get(),
      activities(roomId).get(),
    ]);
    final recovered = <String>{};
    for (final collection in collections) {
      for (final doc in collection.docs) {
        final data = doc.data();
        for (final key in [
          'paidBy',
          'createdBy',
          'fromUserId',
          'toUserId',
          'performedBy',
        ]) {
          if (data[key] is String && (data[key] as String).isNotEmpty)
            recovered.add(data[key]);
        }
        recovered.addAll(List<String>.from(data['splitAmong'] ?? []));
        final metadata = data['metadata'];
        if (metadata is Map && metadata['memberId'] is String)
          recovered.add(metadata['memberId']);
      }
    }
    await db.runTransaction((transaction) async {
      final ref = rooms.doc(roomId);
      final data = (await transaction.get(ref)).data();
      if (data == null || data['adminId'] != userId)
        throw Exception('Only the admin can restore historical access.');
      transaction.update(ref, {
        'participantIds': {
          ...List<String>.from(data['participantIds'] ?? []),
          ...List<String>.from(data['memberIds'] ?? []),
          ...recovered,
        }.toList(),
        'ledgerVersion': FieldValue.increment(1),
      });
      _activity(
        transaction,
        roomId,
        userId,
        'roomSettingsChanged',
        'Historical participants restored from room records',
        null,
      );
    });
  }

  void _activity(
    Transaction transaction,
    String roomId,
    String userId,
    String type,
    String description,
    Map<String, dynamic>? metadata,
  ) {
    transaction.set(activities(roomId).doc(), {
      'type': type,
      'performedBy': userId,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    });
  }
}
