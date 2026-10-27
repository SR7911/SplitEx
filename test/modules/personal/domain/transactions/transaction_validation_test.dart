import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/transaction_validation.dart';

void main() {
  PersonalTransaction transaction({double amount = 10, DateTime? dueDate}) =>
      PersonalTransaction(
        id: '',
        title: 'Lunch',
        amount: amount,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2025, 8, 2, 18),
        userId: 'user-1',
        month: '2025-08',
        createdAt: DateTime(2025, 8, 2),
        dueDate: dueDate,
      );

  test('requires a finite positive amount', () {
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => validatePersonalTransactionForCreate(transaction(amount: amount)),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('allows same-day due date and rejects earlier calendar day', () {
    expect(
      () => validatePersonalTransactionForCreate(
        transaction(dueDate: DateTime(2025, 8, 2)),
      ),
      returnsNormally,
    );
    expect(
      () => validatePersonalTransactionForCreate(
        transaction(dueDate: DateTime(2025, 8, 1, 23)),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
