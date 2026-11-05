import '../entities/room_model.dart';

abstract interface class RoomRepository {
  Future<RoomModel> createRoom(String name, String userId);
  Future<RoomModel?> joinRoom(String inviteCode, String userId);
  Stream<List<RoomModel>> getUserRoomsStream(String userId);
  Stream<RoomModel?> getRoomStream(String roomId);
  Future<void> removeMember(
    String roomId,
    String userId, {
    required String performedBy,
  });
  Future<void> leaveRoom(String roomId, String userId);
  Future<void> transferAdmin(String roomId, String adminId, String newAdminId);
  Future<void> setArchived(String roomId, String userId, bool archived);
  Future<void> restoreHistoricalParticipants(String roomId, String userId);
}
