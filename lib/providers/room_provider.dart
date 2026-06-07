import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/room_model.dart';
import 'package:split_ex/models/user_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/services/room_service.dart';
import 'package:split_ex/services/user_service.dart';

final roomServiceProvider = Provider<RoomService>((ref) => RoomService());

final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.uid ?? '';
});

final isDeveloperProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  final email = authState.valueOrNull?.email ?? '';
  return (email == 'sudharsan7911@gmail.com' || email == 'sudharsansr7911@gmail.com' || email == 'developersr7911@gmail.com') ? 'Y' : 'N';
});

final userRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(roomServiceProvider).getUserRoomsStream(userId);
});

final currentRoomProvider = StateProvider<RoomModel?>((ref) => null);

final roomStreamProvider = StreamProvider.family<RoomModel?, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).getRoomStream(roomId);
});

final roomMembersProvider = FutureProvider.family<List<UserModel>, List<String>>((ref, memberIds) async {
  final userService = UserService();
  final members = <UserModel>[];
  for (final id in memberIds) {
    final user = await userService.getUserProfile(id);
    if (user != null) members.add(user);
  }
  return members;
});
