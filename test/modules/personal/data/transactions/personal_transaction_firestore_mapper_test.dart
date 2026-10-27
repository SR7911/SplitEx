import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../support/personal_transaction_fixture.dart';
import 'package:split_ex/modules/personal/data/mappers/transactions/personal_transaction_firestore_mapper.dart';

void main() {
  test('reads existing debt fields and legacy defaults', () {
    final date = DateTime(2025, 8, 2);
    final map = <String, dynamic>{
      'title': 'Shared loan',
      'amount': 250,
      'type': 'expense',
      'category': 'Loans',
      'date': Timestamp.fromDate(date),
      'userId': 'user-1',
      'month': '2025-08',
      'createdAt': Timestamp.fromDate(date),
      'accountId': 'wallet-1',
      'dueDate': Timestamp.fromDate(DateTime(2025, 9, 2)),
      'debtType': 'lent',
      'personName': 'Alex',
      'isSettled': false,
      'settledAmount': 50,
      'writtenOffAmount': 10,
      'partialSettlements': <Map<String, dynamic>>[
        {'amount': 50},
      ],
    };
    final transaction = PersonalTransactionFirestoreMapper.fromMap(map, 't-1');
    final legacy = PersonalTransactionModel.fromMap(map, 't-1');

    expect(transaction.id, 't-1');
    expect(transaction.remainingAmount, 190);
    expect(transaction.settlements, hasLength(1));
    expect(transaction.settlements.single.amount, 50);
    expect(transaction.settlements.single.date, isNull);
    expect(transaction.dueDate, DateTime(2025, 9, 2));
    expect(legacy.partialSettlements, [
      {'amount': 50},
    ]);
    expect(legacy.remainingAmount, transaction.remainingAmount);
    expect(legacy.settlements.single.amount, 50);

    final defaults = PersonalTransactionFirestoreMapper.fromMap({}, 'old');
    expect(defaults.type, TransactionType.expense);
    expect(defaults.category, 'Other');
    expect(defaults.amount, 0);
    expect(defaults.accountId, isNull);
  });

  test('preserves the transaction write schema', () {
    final transaction = PersonalTransactionModel(
      id: 't-1',
      title: 'Expense',
      amount: 42,
      type: TransactionType.expense,
      category: 'Food',
      date: DateTime(2025, 8, 2),
      userId: 'user-1',
      month: '2025-08',
      createdAt: DateTime(2025, 8, 2),
      partialSettlements: const [
        {'amount': 12},
      ],
    );
    final pureMap = PersonalTransactionFirestoreMapper.toMap(transaction);
    final legacyMap = transaction.toMap();

    expect(pureMap.keys, isNot(contains('partialSettlements')));
    expect(pureMap.keys, isNot(contains('accountId')));
    expect(pureMap['createdAt'], isA<FieldValue>());
    expect(legacyMap.keys, containsAll(pureMap.keys));
    expect(legacyMap['partialSettlements'], [
      {'amount': 12},
    ]);
    for (final key in pureMap.keys.where((key) => key != 'createdAt')) {
      expect(legacyMap[key], pureMap[key]);
    }
  });
}
