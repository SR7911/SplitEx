import '../../entities/accounts/personal_account.dart';
import '../../policies/accounts/account_validation.dart';
import '../../repositories/personal_account_repository.dart';

class SavePersonalAccount {
  final PersonalAccountRepository _repository;
  const SavePersonalAccount(this._repository);

  Future<void> call(String userId, PersonalAccount account) async {
    validatePersonalAccount(account);
    await _repository.saveAccount(userId, account);
  }
}
