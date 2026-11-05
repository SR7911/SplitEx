import 'package:split_ex/shared/domain/entities/settlement_model.dart';

abstract interface class SettlementRepository {
  Future<String> createSettlement(String roomId, SettlementModel settlement);
  Future<void> confirmSettlement(
    String roomId,
    String settlementId, {
    required String performedBy,
  });
  Future<void> cancelSettlement(
    String roomId,
    String settlementId, {
    required String performedBy,
  });
  Future<void> addUpiRef(
    String roomId,
    String settlementId,
    String upiRef, {
    required String performedBy,
  });
  Stream<List<SettlementModel>> getSettlementsStream(String roomId);
  Stream<List<SettlementModel>> getPendingSettlementsStream(
    String roomId,
    String userId,
  );
}
