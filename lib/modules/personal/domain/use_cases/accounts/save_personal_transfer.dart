import '../../entities/accounts/personal_transfer.dart';
import '../../policies/accounts/account_validation.dart';
import '../../repositories/personal_account_repository.dart';

class SavePersonalTransfer {
  final PersonalAccountRepository _repository;
  const SavePersonalTransfer(this._repository);

  Future<void> call(String userId, PersonalTransfer transfer) async {
    validatePersonalTransfer(transfer);
    await _repository.saveTransfer(userId, transfer);
  }
}
