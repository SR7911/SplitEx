import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/personal_transaction_model.dart';

enum PersonalAccountType { cash, bank, creditCard }

class PersonalAccount {
  final String id, name;
  final PersonalAccountType type;

  /// Signed balance before any assigned entries: card debt is negative.
  final double openingBalance;
  final String? last4;
  final bool archived;
  const PersonalAccount({
    required this.id,
    required this.name,
    required this.type,
    this.openingBalance = 0,
    this.last4,
    this.archived = false,
  });

  factory PersonalAccount.fromMap(Map<String, dynamic> map, String id) =>
      PersonalAccount(
        id: id,
        name: map['name'] as String? ?? 'Account',
        type: PersonalAccountType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => PersonalAccountType.bank,
        ),
        openingBalance: (map['openingBalance'] as num? ?? 0).toDouble(),
        last4: map['last4'] as String?,
        archived: map['archived'] == true,
      );
  String get typeLabel => switch (type) {
    PersonalAccountType.cash => 'Cash',
    PersonalAccountType.bank => 'Bank account',
    PersonalAccountType.creditCard => 'Credit card',
  };
  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.name,
    'openingBalance': openingBalance,
    'last4': last4,
    'archived': archived,
  };
}

class PersonalTransfer {
  final String id, fromAccountId, toAccountId;
  final double amount;
  final DateTime date;
  final String? note;
  const PersonalTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.date,
    this.note,
  });
  factory PersonalTransfer.fromMap(Map<String, dynamic> map, String id) =>
      PersonalTransfer(
        id: id,
        fromAccountId: map['fromAccountId'] as String,
        toAccountId: map['toAccountId'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: (map['date'] as Timestamp).toDate(),
        note: map['note'] as String?,
      );
  Map<String, dynamic> toMap() => {
    'fromAccountId': fromAccountId,
    'toAccountId': toAccountId,
    'amount': amount,
    'date': Timestamp.fromDate(date),
    'note': note,
  };
}

Map<String, double> calculateAccountBalances(
  List<PersonalAccount> accounts,
  List<PersonalTransactionModel> transactions,
  List<PersonalTransfer> transfers,
) {
  // Calculate from records so edits, deletes and retries cannot drift balances.
  final balances = {
    for (final a in accounts) a.id: (a.openingBalance * 100).round(),
  };
  for (final t in transactions) {
    if (balances.containsKey(t.accountId)) {
      final value = (t.amount * 100).round();
      balances[t.accountId!] =
          balances[t.accountId!]! + (t.isIncome ? value : -value);
    }
  }
  for (final t in transfers) {
    final value = (t.amount * 100).round();
    if (balances.containsKey(t.fromAccountId)) {
      balances[t.fromAccountId] = balances[t.fromAccountId]! - value;
    }
    if (balances.containsKey(t.toAccountId)) {
      balances[t.toAccountId] = balances[t.toAccountId]! + value;
    }
  }
  return balances.map((key, value) => MapEntry(key, value / 100));
}
