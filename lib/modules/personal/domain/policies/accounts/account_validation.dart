import '../../entities/accounts/personal_account.dart';
import '../../entities/accounts/personal_transfer.dart';

void validatePersonalAccount(PersonalAccount account) {
  if (account.name.trim().isEmpty ||
      !account.openingBalance.isFinite ||
      (account.last4 != null && !RegExp(r'^\d{4}$').hasMatch(account.last4!))) {
    throw StateError(
      'Enter an account name, valid balance and four-digit ending.',
    );
  }
}

void validatePersonalTransfer(PersonalTransfer transfer) {
  if (transfer.fromAccountId == transfer.toAccountId ||
      !transfer.amount.isFinite ||
      transfer.amount <= 0 ||
      (transfer.amount * 100).round() == 0) {
    throw StateError('Choose different accounts and a positive amount.');
  }
}
