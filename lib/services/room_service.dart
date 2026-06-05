import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/config/constants.dart';
import 'package:split_ex/models/room_model.dart';

class RoomService {
  final _roomsRef = FirebaseFirestore.instance.collection('rooms');
  final _usersRef = FirebaseFirestore.instance.collection('users');

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<RoomModel> createRoom(String name, String userId) async {
    final doc = _roomsRef.doc();
    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);

    final room = RoomModel(
      id: doc.id,
      name: name,
      inviteCode: _generateInviteCode(),
      adminId: userId,
      memberIds: [userId],
      createdAt: now,
      currentMonth: currentMonth,
    );

    await doc.set(room.toMap());
    await _usersRef.doc(userId).set({
      'rooms': FieldValue.arrayUnion([doc.id]),
    }, SetOptions(merge: true));

    return room;
  }

  Future<RoomModel?> joinRoom(String inviteCode, String userId) async {
    final query = await _roomsRef
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final room = RoomModel.fromMap(doc.data(), doc.id);

    if (room.isMember(userId)) return room;
    if (room.memberIds.length >= AppConstants.maxRoomMembers) {
      throw Exception('Room is full (max ${AppConstants.maxRoomMembers} members)');
    }

    await _roomsRef.doc(doc.id).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    await _usersRef.doc(userId).set({
      'rooms': FieldValue.arrayUnion([doc.id]),
    }, SetOptions(merge: true));

    return RoomModel.fromMap(doc.data(), doc.id);
  }

  Stream<List<RoomModel>> getUserRoomsStream(String userId) {
    return _roomsRef
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RoomModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<RoomModel?> getRoomStream(String roomId) {
    return _roomsRef.doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RoomModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> removeMember(String roomId, String userId) async {
    await _roomsRef.doc(roomId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
    await _usersRef.doc(userId).update({
      'rooms': FieldValue.arrayRemove([roomId]),
    });
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    await removeMember(roomId, userId);
  }
}
