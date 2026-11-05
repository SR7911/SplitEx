import '../repositories/room_repository.dart';

/// Prevents an unreachable account remaining in future expense splits.
class EnsureRoomExitBeforeAccountDeletion {
  final RoomRepository rooms;
  const EnsureRoomExitBeforeAccountDeletion(this.rooms);

  Future<void> call(String userId) async {
    final memberships = await rooms.getUserRoomsStream(userId).first;
    if (memberships.any((room) => room.isMember(userId))) {
      throw Exception(
        'Leave your rooms before deleting your account. Transfer admin responsibility first where needed. Shared history will be preserved.',
      );
    }
  }
}
