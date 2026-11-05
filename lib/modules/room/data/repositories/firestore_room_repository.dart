import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/data/datasources/room_firestore_data_source.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/modules/room/domain/policies/room_limits.dart';
import 'package:split_ex/modules/room/domain/repositories/room_repository.dart';

class FirestoreRoomRepository implements RoomRepository {
  final RoomFirestoreDataSource source;
  FirestoreRoomRepository({
    FirebaseFirestore? firestore,
    RoomFirestoreDataSource? source,
  }) : source = source ?? RoomFirestoreDataSource(firestore: firestore);

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<RoomModel> createRoom(String name, String userId) async {
    name = name.trim();
    if (name.isEmpty || userId.isEmpty)
      throw Exception('Enter a room name and sign in first.');
    final id = source.rooms.doc().id;
    final now = DateTime.now();
    final room = RoomModel(
      id: id,
      name: name,
      inviteCode: _generateInviteCode(),
      adminId: userId,
      memberIds: [userId],
      createdAt: now,
      currentMonth: DateFormat('yyyy-MM').format(now),
    );
    await source.createRoom(id, RoomFirestoreMapper.toMap(room), userId);
    return room;
  }

  @override
  Future<RoomModel?> joinRoom(String inviteCode, String userId) async {
    final document = await source.joinRoom(
      inviteCode,
      userId,
      maxMembers: RoomLimits.maxMembers,
    );
    return document == null
        ? null
        : RoomFirestoreMapper.fromMap(document.$2, document.$1);
  }

  @override
  Stream<List<RoomModel>> getUserRoomsStream(String userId) => source.rooms
      .where(
        Filter.or(
          Filter('memberIds', arrayContains: userId),
          Filter('participantIds', arrayContains: userId),
        ),
      )
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => RoomFirestoreMapper.fromMap(doc.data(), doc.id))
                .toList()
              ..sort((a, b) {
                final aActive = a.isMember(userId) && !a.isArchived;
                final bActive = b.isMember(userId) && !b.isArchived;
                if (aActive != bActive) return aActive ? -1 : 1;
                return b.createdAt.compareTo(a.createdAt);
              }),
      );

  @override
  Stream<RoomModel?> getRoomStream(String roomId) => source.rooms
      .doc(roomId)
      .snapshots()
      .map(
        (doc) => doc.exists
            ? RoomFirestoreMapper.fromMap(doc.data()!, doc.id)
            : null,
      );

  @override
  Future<void> removeMember(
    String roomId,
    String userId, {
    required String performedBy,
  }) => source.removeMember(roomId, userId, performedBy: performedBy);
  @override
  Future<void> leaveRoom(String roomId, String userId) =>
      source.removeMember(roomId, userId, performedBy: userId);

  @override
  Future<void> transferAdmin(
    String roomId,
    String adminId,
    String newAdminId,
  ) => source.transferAdmin(roomId, adminId, newAdminId);

  @override
  Future<void> setArchived(String roomId, String userId, bool archived) =>
      source.setArchived(roomId, userId, archived);

  @override
  Future<void> restoreHistoricalParticipants(String roomId, String userId) =>
      source.restoreHistoricalParticipants(roomId, userId);
}
