import 'package:split_ex/shared/domain/entities/debt.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';
import '../repositories/group_settlement_repository.dart';

class RecordGroupSettlement {
  final GroupSettlementRepository settlements;
  const RecordGroupSettlement(this.settlements);

  Future<void> call(String groupId, Debt debt) => settlements.createSettlement(
    groupId,
    SettlementModel(
      id: '',
      roomId: groupId,
      fromUserId: debt.from,
      toUserId: debt.to,
      amount: debt.amount,
      createdAt: DateTime.now(),
    ),
  );
}
