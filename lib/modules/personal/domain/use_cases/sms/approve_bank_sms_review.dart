import '../../policies/sms/bank_sms_parser.dart';
import '../../repositories/bank_sms_device_gateway.dart';
import '../../repositories/bank_sms_repository.dart';

class ApproveBankSmsReview {
  final PersonalBankSmsRepository repository;
  final BankSmsDeviceGateway device;
  const ApproveBankSmsReview(this.repository, this.device);

  Future<BankSmsSaveResult> call({
    required String userId,
    required ParsedBankSms sms,
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    required BankSmsDirection direction,
    required bool Function() isActive,
    String? existingId,
    List<BankSmsDebtAllocation>? debtAllocations,
    String? accountId,
    bool asTransfer = false,
    String? fromAccountId,
    String? toAccountId,
    bool trustSender = false,
    bool rememberCategory = false,
  }) async {
    final result = debtAllocations != null
        ? await repository.saveDebtSettlement(
            userId,
            sms,
            allocations: debtAllocations,
            accountId: accountId,
            date: date,
          )
        : asTransfer
        ? await repository.saveTransfer(
            userId,
            sms,
            existingId: existingId,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            date: date,
            note: title,
          )
        : await repository.save(
            userId,
            sms,
            existingId: existingId,
            accountId: accountId,
            title: title,
            amount: amount,
            category: category,
            date: date,
            direction: direction,
            rememberCategory: rememberCategory,
          );
    if (!isActive()) return result;
    if (trustSender && sms.source == 'sms') {
      await device.trust(userId, sms.sender, true);
    }
    if (isActive()) await device.deleteReview(userId, sms.messageId);
    return result;
  }
}
