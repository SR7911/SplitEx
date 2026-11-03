import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/data/models/personal_transaction_firestore_model.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_bank_sms_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/accounts/account_balance_calculator.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/shared_expense_progress.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/personal_transactions_screen.dart';
import 'package:split_ex/modules/personal/presentation/transactions/widgets/shared_expense_details.dart';
import 'package:split_ex/modules/settings/models/expenses_widget_snapshot.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';
import 'package:split_ex/shared/ui/theme.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _date = DateTime(2026, 11, 2);
ParsedBankSms _sms(String id, double amount, BankSmsDirection direction) =>
    ParsedBankSms(
      messageId: id,
      sender: 'VM-TESTBK',
      body: 'Private bank message',
      amountMinor: (amount * 100).round(),
      direction: direction,
      date: _date,
    );
const _split = ExpenseSplit(
  mode: ExpenseSplitMode.manual,
  shares: [ExpenseSplitShare(personName: 'Alex', amount: 45)],
);

class _Online extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _Online() : super(ConnectivityStatus.online);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late FirestoreBankSmsRepository repo;
  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreBankSmsRepository(firestore: db);
  });

  Future<(PersonalTransaction, PersonalTransaction)> createShared() async {
    await db.doc('users/alice/personal_accounts/bank').set({
      'name': 'Bank',
      'archived': false,
    });
    await repo.save(
      'alice',
      _sms('purchase', 100, BankSmsDirection.debit),
      title: 'Shared lunch',
      category: 'Food',
      split: _split,
      notes: 'Lunch with Alex',
      accountId: 'bank',
      dueDate: DateTime(2026, 11, 5),
    );
    final docs =
        (await db.collection('users/alice/personal_transactions').get()).docs;
    final entries = docs
        .map(
          (doc) =>
              PersonalTransactionFirestoreMapper.fromMap(doc.data(), doc.id),
        )
        .toList();
    return (
      entries.singleWhere((entry) => entry.split != null),
      entries.singleWhere((entry) => entry.splitSourceId != null),
    );
  }

  Future<PersonalTransaction> readDebt(String id) async {
    final snapshot = await db
        .doc('users/alice/personal_transactions/$id')
        .get();
    return PersonalTransactionFirestoreMapper.fromMap(snapshot.data()!, id);
  }

  test(
    '100 paid, 45 returned produces 55 spending without changing cash or the original payment',
    () async {
      final (parent, debt) = await createShared();
      expect(parent.split!.ownShareCents(parent.amount), 5500);
      expect(parent.notes, contains('Lunch with Alex'));
      expect(debt.accountId, isNull);
      expect(
        calculatePersonalMonthlySummary(
          [parent],
          debts: [debt],
          month: parent.month,
        ).expenses,
        100,
      );
      final payment = _sms('repayment', 45, BankSmsDirection.credit);
      await repo.saveDebtSettlement(
        'alice',
        payment,
        allocations: [
          BankSmsDebtAllocation(debtId: debt.id, amountMinor: 4500),
        ],
        accountId: 'bank',
      );
      final settled = await readDebt(debt.id);
      final summary = calculatePersonalMonthlySummary(
        [parent],
        debts: [settled],
        month: parent.month,
      );
      expect(summary.expenses, 55);
      expect(summary.cashExpenses, 100);
      expect(summary.cashIncome, 45);
      expect(calculatePersonalCategorySpending([parent], debts: [settled]), {
        'Food': 55,
      });
      final projected = attachSharedExpenseDebts([parent], [settled]).single;
      expect(projected.sharedStatus, 'Settled');
      expect(projected.sharedRemainingAmount, 0);
      expect(projected.amount, 100);
      expect(
        ExpensesWidgetSnapshot.fromTransactions(
          userId: 'alice',
          monthKey: parent.month,
          transactions: [projected],
        ).expensesMinor,
        5500,
      );
      final balances = calculateAccountBalances(
        const [
          PersonalAccount(
            id: 'bank',
            name: 'Bank',
            type: PersonalAccountType.bank,
            openingBalance: 1000,
          ),
        ],
        [parent],
        const [],
        debts: [settled],
      );
      expect(balances['bank'], 945);
      expect(
        await repo.saveDebtSettlement(
          'alice',
          payment,
          allocations: [
            BankSmsDebtAllocation(debtId: debt.id, amountMinor: 4500),
          ],
        ),
        BankSmsSaveResult.duplicate,
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        hasLength(2),
      );
    },
  );

  test(
    'partial repayment reduces spending by only the returned amount',
    () async {
      final (parent, debt) = await createShared();
      await repo.saveDebtSettlement(
        'alice',
        _sms('partial', 20, BankSmsDirection.credit),
        allocations: [
          BankSmsDebtAllocation(debtId: debt.id, amountMinor: 2000),
        ],
      );
      final projected = attachSharedExpenseDebts(
        [parent],
        [await readDebt(debt.id)],
      ).single;
      expect(projected.spendingAmount, 80);
      expect(projected.sharedStatus, 'Partially settled');
      expect(projected.sharedRemainingAmount, 25);
    },
  );

  test(
    'a later-month reimbursement updates original net spending and only its actual cash month',
    () async {
      final (parent, debt) = await createShared();
      await repo.saveDebtSettlement(
        'alice',
        _sms('later', 45, BankSmsDirection.credit),
        allocations: [
          BankSmsDebtAllocation(debtId: debt.id, amountMinor: 4500),
        ],
        date: DateTime(2026, 12, 1),
      );
      final settled = await readDebt(debt.id);
      final original = calculatePersonalMonthlySummary(
        [parent],
        debts: [settled],
        month: '2026-11',
      );
      final later = calculatePersonalMonthlySummary(
        [],
        debts: [settled],
        month: '2026-12',
      );
      expect(original.expenses, 55);
      expect(original.cashIncome, 0);
      expect(original.cashExpenses, 100);
      expect(later.expenses, 0);
      expect(later.cashIncome, 45);
    },
  );

  test('each participant has an independent remaining balance', () async {
    await repo.save(
      'alice',
      _sms('group', 100, BankSmsDirection.debit),
      split: const ExpenseSplit(
        mode: ExpenseSplitMode.manual,
        shares: [
          ExpenseSplitShare(personName: 'Alex', amount: 35),
          ExpenseSplitShare(personName: 'Sam', amount: 25),
        ],
      ),
    );
    final docs =
        (await db.collection('users/alice/personal_transactions').get()).docs;
    final entries = docs
        .map(
          (doc) =>
              PersonalTransactionFirestoreMapper.fromMap(doc.data(), doc.id),
        )
        .toList();
    final parent = entries.singleWhere((entry) => entry.hasSharedExpense);
    final alex = entries.singleWhere((entry) => entry.personName == 'Alex');
    final sam = entries.singleWhere((entry) => entry.personName == 'Sam');
    await repo.saveDebtSettlement(
      'alice',
      _sms('alex', 35, BankSmsDirection.credit),
      allocations: [BankSmsDebtAllocation(debtId: alex.id, amountMinor: 3500)],
    );
    final projected = attachSharedExpenseDebts(
      [parent],
      [await readDebt(alex.id), sam],
    ).single;
    expect(projected.sharedStatus, 'Partially settled');
    expect(projected.spendingAmount, 65);
    expect(projected.sharedRemainingAmount, 25);
    expect(
      projected.debtForShare(projected.split!.shares.first)!.isSettled,
      isTrue,
    );
  });

  for (final closure in ['writeOff', 'tally']) {
    test(
      '$closure closes a share without pretending its amount was returned',
      () async {
        final (parent, debt) = await createShared();
        await db.doc('users/alice/personal_transactions/${debt.id}').update({
          'isSettled': true,
          'settledAmount': closure == 'tally' ? 45 : 0,
          'writtenOffAmount': closure == 'writeOff' ? 45 : 0,
          'partialSettlements': [
            {'amount': 45, 'date': _date.toIso8601String(), 'type': closure},
          ],
        });
        final projected = attachSharedExpenseDebts(
          [parent],
          [await readDebt(debt.id)],
        ).single;
        expect(projected.sharedStatus, 'Closed');
        expect(projected.spendingAmount, 100);
      },
    );
  }

  test(
    'split import and retries produce one parent, one share and one receipt',
    () async {
      final (parent, debt) = await createShared();
      expect(parent.split!.shares.single.debtId, debt.id);
      expect(
        await repo.save(
          'alice',
          _sms('purchase', 100, BankSmsDirection.debit),
          split: _split,
        ),
        BankSmsSaveResult.duplicate,
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        hasLength(2),
      );
      expect(
        (await db.collection('users/alice/bank_sms_receipts').get()).docs,
        hasLength(1),
      );
    },
  );

  test('invalid split cannot leave an expense or receipt behind', () async {
    await expectLater(
      repo.save(
        'alice',
        _sms('bad', 100, BankSmsDirection.debit),
        split: const ExpenseSplit(
          mode: ExpenseSplitMode.manual,
          shares: [ExpenseSplitShare(personName: 'Alex', amount: 101)],
        ),
      ),
      throwsStateError,
    );
    expect(
      (await db.collection('users/alice/personal_transactions').get()).docs,
      isEmpty,
    );
    expect(
      (await db.collection('users/alice/bank_sms_receipts').get()).docs,
      isEmpty,
    );
  });

  test(
    'SMS can directly record person-involved lending and borrowing',
    () async {
      for (final direction in BankSmsDirection.values) {
        await repo.save(
          'alice',
          _sms(direction.name, 100, direction),
          debtType: direction == BankSmsDirection.debit
              ? DebtType.lent
              : DebtType.borrowed,
          personName: 'Alex',
        );
      }
      final docs =
          (await db.collection('users/alice/personal_transactions').get()).docs;
      expect(docs.map((doc) => doc.data()['debtType']).toSet(), {
        'lent',
        'borrowed',
      });
      expect(docs.every((doc) => doc.data()['personName'] == 'Alex'), isTrue);
    },
  );

  testWidgets(
    'transaction shared status and net amount react to settlement and search by person',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (parent, debt) = await createShared();
      final updates = StreamController<List<PersonalTransaction>>();
      addTearDown(updates.close);
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader(
        'Gilmer',
      )..addFont(rootBundle.load('assets/fonts/Gilmer-Regular.otf'))).load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => _Online()),
            unreadCountProvider.overrideWith((ref) => Stream.value(0)),
            personalMonthTransactionsProvider.overrideWith(
              (ref, _) => Stream.value([parent]),
            ),
            personalDebtTransactionsProvider.overrideWith(
              (ref) => updates.stream,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppPalette.teal),
            home: PersonalTransactionsScreen(monthKey: parent.month),
          ),
        ),
      );
      updates.add([debt]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Shared'), findsNWidgets(2));
      expect(find.text('Pending'), findsOneWidget);
      final spend = find.byKey(ValueKey('transaction-net-spend-${parent.id}'));
      expect(tester.widget<Text>(spend).data, '-₹100');
      expect(find.text('of ₹100'), findsOneWidget);
      await repo.saveDebtSettlement(
        'alice',
        _sms('live-partial', 20, BankSmsDirection.credit),
        allocations: [
          BankSmsDebtAllocation(debtId: debt.id, amountMinor: 2000),
        ],
      );
      updates.add([await readDebt(debt.id)]);
      await tester.pumpAndSettle();
      expect(find.text('Partially settled'), findsOneWidget);
      expect(tester.widget<Text>(spend).data, '-₹80');
      expect(find.text('of ₹100'), findsOneWidget);
      await repo.saveDebtSettlement(
        'alice', _sms('live-final', 25, BankSmsDirection.credit),
        allocations: [BankSmsDebtAllocation(debtId: debt.id, amountMinor: 2500)],
      );
      updates.add([await readDebt(debt.id)]);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(spend).data, '-₹55');
      expect(find.text('of ₹100'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
      final details = find.byType(SharedExpenseDetails);
      expect(find.descendant(of: details, matching: find.text('Your share')), findsOneWidget);
      expect(find.descendant(of: details, matching: find.text('₹55')), findsOneWidget);
      expect(find.descendant(of: details, matching: find.text('Repaid')), findsOneWidget);
      expect(find.descendant(of: details, matching: find.text('₹45')), findsNWidgets(2));
      expect(find.descendant(of: details, matching: find.text('Alex')), findsOneWidget);
      final search = find.byType(TextField).first;
      final field = tester.widget<TextField>(search);
      expect(
        field.decoration!.fillColor,
        AppTheme.lightTheme(AppPalette.teal).colorScheme.surface,
      );
      await tester.enterText(search, 'Alex');
      await tester.pumpAndSettle();
      expect(find.text('Shared lunch'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
