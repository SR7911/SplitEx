import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/app/auth/models/user_model.dart';
import 'package:split_ex/app/auth/services/user_service.dart';

final userProfilesByIdsProvider =
    FutureProvider.family<List<UserModel>, List<String>>((ref, userIds) async {
  final userService = UserService();
  final members = <UserModel>[];
  for (final id in userIds) {
    final user = await userService.getUserProfile(id);
    if (user != null) members.add(user);
  }
  return members;
});
