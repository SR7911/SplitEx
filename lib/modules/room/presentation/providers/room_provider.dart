import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/modules/room/dependencies.dart';
export 'package:split_ex/modules/room/dependencies.dart' show roomServiceProvider;

final userRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(roomServiceProvider).getUserRoomsStream(userId);
});

final currentRoomProvider = StateProvider<RoomModel?>((ref) => null);

final roomStreamProvider = StreamProvider.family<RoomModel?, String>((ref, roomId) {
  return ref.watch(roomServiceProvider).getRoomStream(roomId);
});

