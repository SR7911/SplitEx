import '../entities/room_model.dart';
import '../repositories/room_repository.dart';

class JoinRoom {
  final RoomRepository rooms;
  const JoinRoom(this.rooms);

  Future<RoomModel?> call(String inviteCode, String userId) {
    return rooms.joinRoom(inviteCode.trim().toUpperCase(), userId);
  }
}
