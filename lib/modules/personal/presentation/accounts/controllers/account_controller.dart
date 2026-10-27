import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dependencies.dart';
import '../../../domain/entities/accounts/personal_account.dart';
import '../../../domain/entities/accounts/personal_transfer.dart';
import '../../../domain/repositories/personal_account_repository.dart';
import '../../../domain/use_cases/accounts/save_personal_account.dart';
import '../../../domain/use_cases/accounts/save_personal_transfer.dart';

final accountControllerProvider = Provider<AccountController>(
  (ref) => AccountController(ref.watch(personalAccountRepositoryProvider)),
);

/// Write operations shared by account forms. UI feedback stays with the forms.
class AccountController {
  final PersonalAccountRepository _repository;
  final SavePersonalAccount _saveAccount;
  final SavePersonalTransfer _saveTransfer;

  AccountController(PersonalAccountRepository repository)
    : _repository = repository,
      _saveAccount = SavePersonalAccount(repository),
      _saveTransfer = SavePersonalTransfer(repository);

  Future<void> saveAccount(String userId, PersonalAccount account) =>
      _saveAccount(userId, account);
  Future<void> saveTransfer(String userId, PersonalTransfer transfer) =>
      _saveTransfer(userId, transfer);
  Future<void> archive(String userId, String id, bool archived) =>
      _repository.archive(userId, id, archived);
  Future<void> deleteTransfer(String userId, String id) =>
      _repository.deleteTransfer(userId, id);
}
