import '../entities/transactions/debt_settlement_command.dart';
import '../entities/transactions/personal_transaction.dart';
import '../entities/transactions/personal_transaction_edit.dart';

abstract class PersonalTransactionRepository {
  Stream<List<PersonalTransaction>> transactionsForMonth(
    String userId,
    String month,
  );
  Stream<List<PersonalTransaction>> debts(String userId);

  /// Create a transaction only when its assigned account is still active.
  Future<void> create(String userId, PersonalTransaction transaction);
  Future<void> update(String userId, String id, PersonalTransactionEdit edit);
  Future<void> delete(String userId, String id);
  Future<void> settleDebt(
    String userId,
    String id,
    DebtSettlementCommand command,
  );
}
