import 'package:split_ex/shared/domain/entities/settlement_model.dart';

abstract interface class GroupSettlementRepository {
  Future<void> createSettlement(String groupId, SettlementModel settlement);
  Future<void> confirmSettlement(String groupId, String settlementId);
  Future<void> cancelSettlement(String groupId, String settlementId);
  Stream<List<SettlementModel>> getSettlementsStream(String groupId);
}
