import '../entities/group_model.dart';
import '../repositories/group_repository.dart';

class JoinGroup {
  final GroupRepository groups;
  const JoinGroup(this.groups);

  Future<GroupModel?> call(String inviteCode, String userId) async {
    final group = await groups.findByInviteCode(
      inviteCode.trim().toUpperCase(),
    );
    if (group == null) return null;
    if (group.isArchived) throw Exception('This group is archived.');
    if (group.isMember(userId)) throw Exception('Already a member.');
    return groups.addMember(group.id, userId);
  }
}
