import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/room/data/models/room_firestore_models.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_bill_update.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';

void main() {
  test('Room edit payloads retain Firestore dates and fields', () {
    final date = DateTime(2026, 10, 29);
    final expense = ExpenseFirestoreMapper.toUpdateMap(
      RoomExpenseUpdate(
        title: 'Dinner',
        amount: 450,
        category: 'Food',
        date: date,
        splitType: SplitType.equal,
        splitAmong: const ['a', 'b'],
        month: '2026-10',
      ),
    );
    expect(expense['date'], isA<Timestamp>());
    expect((expense['date'] as Timestamp).toDate(), date);
    expect(expense['splitType'], 'equal');
    expect(expense['month'], '2026-10');
    expect(expense, isNot(contains('paidBy')));
    expect(expense, contains('updatedAt'));

    final bill = BillFirestoreMapper.toUpdateMap(
      RoomBillUpdate(
        type: BillType.rent,
        amount: 10000,
        date: date,
        month: '2026-10',
      ),
    );
    expect(bill['date'], isA<Timestamp>());
    expect((bill['date'] as Timestamp).toDate(), date);
    expect(bill['type'], 'rent');
    expect(bill['month'], '2026-10');
  });
}
