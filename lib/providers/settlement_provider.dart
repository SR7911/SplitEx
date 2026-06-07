import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/settlement_model.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/settlement_service.dart';
import 'package:split_ex/services/upi_service.dart';

final settlementServiceProvider =
    Provider<SettlementService>((ref) => SettlementService());

final upiServiceProvider = Provider<UpiService>((ref) => UpiService());

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