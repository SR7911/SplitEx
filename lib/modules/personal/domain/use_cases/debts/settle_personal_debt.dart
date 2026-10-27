import '../../entities/transactions/debt_settlement_command.dart';
import '../../repositories/personal_transaction_repository.dart';

class SettlePersonalDebt {
  final PersonalTransactionRepository _repository;
  const SettlePersonalDebt(this._repository);

  Future<void> call(
    String userId,
    String id,
    DebtSettlementCommand command,
  ) async {
    if (command.action == DebtSettlementAction.partial) {
      final amount = command.amount;
      if (amount == null || !amount.isFinite || amount <= 0) {
        throw StateError(
          'Amount must be between zero and the remaining balance.',
        );
      }
    }
    await _repository.settleDebt(userId, id, command);
  }
}
