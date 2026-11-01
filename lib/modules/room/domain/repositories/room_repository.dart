import '../entities/room_model.dart';

abstract interface class RoomRepository {
  Future<RoomModel> createRoom(String name, String userId);
  Future<RoomModel?> joinRoom(String inviteCode, String userId);
  Stream<List<RoomModel>> getUserRoomsStream(String userId);
  Stream<RoomModel?> getRoomStream(String roomId);
  Future<void> removeMember(String roomId, String userId);
  Future<void> leaveRoom(String roomId, String userId);
}
