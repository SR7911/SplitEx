import '../../entities/transactions/personal_transaction.dart';
import '../../policies/transactions/transaction_validation.dart';
import '../../repositories/personal_transaction_repository.dart';

class CreatePersonalTransaction {
  final PersonalTransactionRepository _repository;
  const CreatePersonalTransaction(this._repository);

  Future<void> call(String userId, PersonalTransaction transaction) async {
    validatePersonalTransactionForCreate(transaction);
    await _repository.create(userId, transaction);
  }
}
