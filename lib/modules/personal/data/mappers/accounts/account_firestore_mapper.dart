import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/accounts/personal_account.dart';
import '../../../domain/entities/accounts/personal_transfer.dart';

class AccountFirestoreMapper {
  static PersonalAccount fromMap(Map<String, dynamic> map, String id) =>
      PersonalAccount(
        id: id,
        name: map['name'] as String? ?? 'Account',
        type: PersonalAccountType.values.firstWhere(
          (value) => value.name == map['type'],
          orElse: () => PersonalAccountType.bank,
        ),
        openingBalance: (map['openingBalance'] as num? ?? 0).toDouble(),
        last4: map['last4'] as String?,
        archived: map['archived'] == true,
      );

  static Map<String, dynamic> toMap(PersonalAccount account) => {
    'name': account.name,
    'type': account.type.name,
    'openingBalance': account.openingBalance,
    'last4': account.last4,
    'archived': account.archived,
  };
}

class TransferFirestoreMapper {
  static PersonalTransfer fromMap(Map<String, dynamic> map, String id) =>
      PersonalTransfer(
        id: id,
        fromAccountId: map['fromAccountId'] as String,
        toAccountId: map['toAccountId'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: (map['date'] as Timestamp).toDate(),
        note: map['note'] as String?,
      );

  static Map<String, dynamic> toMap(PersonalTransfer transfer) => {
    'fromAccountId': transfer.fromAccountId,
    'toAccountId': transfer.toAccountId,
    'amount': transfer.amount,
    'date': Timestamp.fromDate(transfer.date),
    'note': transfer.note,
  };
}

// Temporary source compatibility for existing fixtures and unmigrated callers.
// New code uses explicit mappers; these extensions are never imported by domain.
extension LegacyAccountSerialization on PersonalAccount {
  Map<String, dynamic> toMap() => AccountFirestoreMapper.toMap(this);
}

extension LegacyTransferSerialization on PersonalTransfer {
  Map<String, dynamic> toMap() => TransferFirestoreMapper.toMap(this);
}
