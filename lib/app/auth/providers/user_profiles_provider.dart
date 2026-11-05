import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:split_ex/app/auth/models/user_model.dart';
import 'package:split_ex/app/auth/services/user_service.dart';

// Family keys compare by value. Fresh lists produced by historical participant
// projections must reuse the same request instead of reloading on every build.
FutureProvider<List<UserModel>> userProfilesByIdsProvider(
  List<String> userIds,
) => _userProfilesByIdsProvider(jsonEncode(userIds.toSet().toList()..sort()));

final _userProfilesByIdsProvider =
    FutureProvider.family<List<UserModel>, String>((ref, key) async {
      final userIds = List<String>.from(jsonDecode(key));
      final userService = UserService();
      final members = <UserModel>[];
      for (final id in userIds) {
        final user = await userService.getUserProfile(id);
        if (user != null) members.add(user);
      }
      return members;
    });
