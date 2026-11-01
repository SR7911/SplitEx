import '../entities/group_model.dart';

abstract interface class GroupRepository {
  Future<GroupModel> createGroup({
    required String name,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required String createdBy,
    String currency,
  });
  Future<GroupModel?> findByInviteCode(String inviteCode);
  Future<GroupModel> addMember(String groupId, String userId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<void> archiveGroup(String groupId);
  Future<void> restoreGroup(String groupId);
  Stream<List<GroupModel>> getUserGroupsStream(String userId);
  Stream<GroupModel?> getGroupStream(String groupId);
}
