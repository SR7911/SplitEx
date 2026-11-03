import '../policies/sms/bank_sms_parser.dart';
import '../entities/transactions/personal_transaction.dart';
import '../entities/transactions/expense_split.dart';

class BankSmsMatch {
  final String id, title;
  final double amount;
  final DateTime date;
  final bool isTransfer;
  const BankSmsMatch({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.isTransfer = false,
  });
}

enum BankSmsSaveResult { recorded, duplicate }

/// One portion of a reviewed bank payment applied to an existing debt.
class BankSmsDebtAllocation {
  final String debtId;
  final int amountMinor;

  const BankSmsDebtAllocation({
    required this.debtId,
    required this.amountMinor,
  });
}

abstract class PersonalBankSmsRepository {
  Future<bool> wasRecorded(String uid, ParsedBankSms sms);
  Future<String?> suggestedCategory(String uid, ParsedBankSms sms);
  Future<List<BankSmsMatch>> possibleMatches(String uid, ParsedBankSms sms);
  Future<List<PersonalTransaction>> openDebtsForSms(
    String uid,
    ParsedBankSms sms,
  );
  Future<BankSmsSaveResult> saveDebtSettlement(
    String uid,
    ParsedBankSms sms, {
    required List<BankSmsDebtAllocation> allocations,
    String? accountId,
    DateTime? date,
  });
  Future<BankSmsSaveResult> saveTransfer(
    String uid,
    ParsedBankSms sms, {
    String? existingId,
    String? fromAccountId,
    String? toAccountId,
    double? amount,
    DateTime? date,
    String? note,
  });
  Future<BankSmsSaveResult> save(
    String uid,
    ParsedBankSms sms, {
    String? existingId,
    String? title,
    double? amount,
    String category = 'Other',
    DateTime? date,
    BankSmsDirection? direction,
    String? accountId,
    bool matchAccount = false,
    bool applyMerchantRule = false,
    bool rememberCategory = false,
    ExpenseSplit? split,
    DebtType? debtType,
    String? personName,
    DateTime? dueDate,
    String? notes,
  });
}
