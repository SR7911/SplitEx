import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/models/personal_transaction_firestore_model.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_transaction_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/debts/debt_tally.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_tally_section.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/shared/ui/theme.dart';

PersonalTransaction _debt(String id, DebtType type, double amount, {
  double paid = 0, bool settled = false, double writtenOff = 0, int day = 1,
}) => PersonalTransaction(
  id: id, title: id, amount: amount, debtType: type, personName: 'Alex',
  type: type == DebtType.lent ? TransactionType.expense : TransactionType.income,
  category: 'Other', date: DateTime(2026, 11, day), userId: 'alice',
  month: '2026-11', createdAt: DateTime(2026, 11, day),
  settledAmount: paid, isSettled: settled, writtenOffAmount: writtenOff,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('closed flags exclude legacy debts even if repayment totals are missing', () {
    final plan = planDebtTally('Alex', [
      _debt('closed-legacy', DebtType.borrowed, 400, settled: true),
      _debt('closed-paid', DebtType.borrowed, 100, paid: 100, settled: true),
      _debt('active', DebtType.borrowed, 500),
      _debt('lent', DebtType.lent, 100, day: 2),
    ]);
    expect(plan.borrowedCents, 50000);
    expect(plan.offsetCents, 10000);
    expect(plan.netCents, -40000);
    expect(plan.offsetsCents, {'active': 10000, 'lent': 10000});
  });

  test('partly repaid debts contribute only their outstanding amount', () {
    final plan = planDebtTally('Alex', [
      _debt('closed', DebtType.borrowed, 400, paid: 400, settled: true),
      _debt('part-paid', DebtType.borrowed, 600, paid: 100, day: 2),
      _debt('lent', DebtType.lent, 100, day: 3),
    ]);
    expect(plan.borrowedCents, 50000);
    expect(plan.netCents, -40000);
    expect(plan.offsetsCents, {'part-paid': 10000, 'lent': 10000});
  });

  test('an offset covers remaining active debts oldest first and can stop partially', () {
    final plan = planDebtTally('Alex', [
      _debt('closed', DebtType.borrowed, 500, settled: true),
      _debt('first-active', DebtType.borrowed, 50, paid: 30, day: 2),
      _debt('second-active', DebtType.borrowed, 480, day: 3),
      _debt('lent', DebtType.lent, 100, day: 4),
    ]);
    expect(plan.offsetsCents, {'first-active': 2000, 'second-active': 8000, 'lent': 10000});
    expect(plan.netCents, -40000);
  });

  test('closed and zero-balance debts cannot create a tally offer', () {
    expect(planDebtTally('Alex', [
      _debt('closed', DebtType.borrowed, 500, settled: true),
      _debt('zero', DebtType.borrowed, 500, paid: 500),
      _debt('lent', DebtType.lent, 100),
    ]).canTally, isFalse);
  });

  for (final splitAcrossDebts in [false, true]) {
    test('confirmation skips closed history and ${splitAcrossDebts ? 'spreads offsets over active debts' : 'leaves the active debt partially settled'}', () async {
      final db = FakeFirebaseFirestore();
      final collection = db.collection('users/alice/personal_transactions');
      final debts = [
        _debt('closed', DebtType.borrowed, 400, settled: true),
        if (splitAcrossDebts) ...[
          _debt('first-active', DebtType.borrowed, 50, paid: 30, day: 2),
          _debt('second-active', DebtType.borrowed, 480, day: 3),
        ] else _debt('part-paid', DebtType.borrowed, 600, paid: 100, day: 2),
        _debt('lent', DebtType.lent, 100, day: 4),
      ];
      for (final debt in debts) {
        await collection.doc(debt.id).set({
          ...PersonalTransactionFirestoreMapper.toMap(debt),
          'partialSettlements': debt.settledAmount > 0 ? [{
            'amount': debt.settledAmount, 'type': 'payment',
            'date': debt.date.toIso8601String(), 'cashEntry': true,
          }] : [],
        });
      }
      final closedBefore = (await collection.doc('closed').get()).data();
      await FirestorePersonalTransactionRepository(firestore: db).tallyDebts(
        'alice', 'Alex', expectedOffsetCents: 10000, expectedNetCents: -40000,
      );
      expect((await collection.doc('closed').get()).data(), closedBefore);
      final lent = (await collection.doc('lent').get()).data()!;
      expect(lent['isSettled'], isTrue);
      expect(lent['settledAmount'], 100);
      final partial = (await collection.doc(splitAcrossDebts ? 'second-active' : 'part-paid').get()).data()!;
      expect(partial['isSettled'], isFalse);
      expect(partial['settledAmount'], splitAcrossDebts ? 80 : 200);
      expect((partial['amount'] as num) - (partial['settledAmount'] as num), 400);
      final history = partial['partialSettlements'] as List;
      expect(history.last['type'], 'tally');
      expect(history.last['cashEntry'], isNull);
      if (splitAcrossDebts) {
        final first = (await collection.doc('first-active').get()).data()!;
        expect(first['isSettled'], isTrue);
        expect(first['settledAmount'], 50);
      } else {
        expect(history.first['amount'], 100);
        expect(history, hasLength(2));
      }
      expect((await collection.get()).docs, hasLength(debts.length));
    });
  }

  test('confirmation rejects a preview after its active debt becomes settled', () async {
    final db = FakeFirebaseFirestore();
    final collection = db.collection('users/alice/personal_transactions');
    for (final debt in [_debt('borrowed', DebtType.borrowed, 500, settled: true),
      _debt('lent', DebtType.lent, 100)]) {
      await collection.doc(debt.id).set(PersonalTransactionFirestoreMapper.toMap(debt));
    }
    await expectLater(FirestorePersonalTransactionRepository(firestore: db).tallyDebts(
      'alice', 'Alex', expectedOffsetCents: 10000, expectedNetCents: -40000,
    ), throwsStateError);
    expect((await collection.doc('lent').get()).data()!['settledAmount'], 0);
  });

  testWidgets('preview shows only active debts and their partial post-tally balance', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Gilmer')..addFont(rootBundle.load('assets/fonts/Gilmer-Regular.otf'))).load();
    final debts = [
      _debt('Already settled borrowing', DebtType.borrowed, 400, settled: true),
      _debt('Active borrowing', DebtType.borrowed, 600, paid: 100, day: 2),
      _debt('Recent lending', DebtType.lent, 100, day: 3),
    ];
    await tester.pumpWidget(ProviderScope(overrides: [
      personalDebtTransactionsProvider.overrideWith((ref) => Stream.value(debts)),
    ], child: MaterialApp(theme: AppTheme.lightTheme(AppPalette.teal),
      home: Scaffold(body: DebtTallySection(debts: debts)))));
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('After tally: ₹400 to repay'), findsOneWidget);
    final list = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListView));
    await tester.drag(list, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Already settled borrowing'), findsNothing);
    expect(find.text('Active borrowing'), findsOneWidget);
    expect(find.text('Borrowed · Active: ₹500'), findsOneWidget);
    expect(find.text('After tally: ₹400 left · Partially settled'), findsOneWidget);
    expect(find.text('After tally: ₹0 left · Settled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
