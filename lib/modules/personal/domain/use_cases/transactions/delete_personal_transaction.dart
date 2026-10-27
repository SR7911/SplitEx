import '../../repositories/personal_transaction_repository.dart';

class DeletePersonalTransaction {
  final PersonalTransactionRepository _repository;
  const DeletePersonalTransaction(this._repository);

  Future<void> call(String userId, String id) => _repository.delete(userId, id);
}
