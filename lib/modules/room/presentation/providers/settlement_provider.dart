import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import 'package:split_ex/modules/room/dependencies.dart';
export 'package:split_ex/modules/room/dependencies.dart' show settlementServiceProvider;
import 'package:split_ex/app/auth/providers/session_provider.dart';

final settlementsStreamProvider =
    StreamProvider.family<List<SettlementModel>, String>((ref, roomId) {
  return ref.watch(settlementServiceProvider).getSettlementsStream(roomId);
});

final pendingSettlementsProvider =
    StreamProvider.family<List<SettlementModel>, String>((ref, roomId) {
  final userId = ref.watch(currentUserIdProvider);
  return ref
      .watch(settlementServiceProvider)
      .getPendingSettlementsStream(roomId, userId);
});
