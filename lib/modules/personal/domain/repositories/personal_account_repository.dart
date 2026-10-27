import '../entities/accounts/personal_account.dart';
import '../entities/accounts/personal_transfer.dart';
import '../entities/transactions/personal_transaction.dart';

abstract class PersonalAccountRepository {
  Stream<List<PersonalAccount>> accounts(String userId);
  Stream<List<PersonalTransfer>> transfers(String userId);
  Stream<List<PersonalTransaction>> assignedTransactions(String userId);
  Future<void> saveAccount(String userId, PersonalAccount account);
  Future<void> archive(String userId, String id, bool archived);

  /// Validate both accounts are active and commit the transfer atomically.
  /// Implementations must recheck account state inside the persistence transaction.
  Future<void> saveTransfer(String userId, PersonalTransfer transfer);
  Future<void> deleteTransfer(String userId, String id);
}
