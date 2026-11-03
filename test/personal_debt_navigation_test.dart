import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/presentation/debts/screens/personal_debts_screen.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/personal_transactions_screen.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';

class _OnlineConnectivity extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _OnlineConnectivity() : super(ConnectivityStatus.online);
}

void main() {
  for (final scenario in ['pending', 'settled', 'multiple']) {
    testWidgets('shared expense opens the correct $scenario share debt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final multiple = scenario == 'multiple';
      final settled = scenario != 'pending';
      final shares = [
        const ExpenseSplitShare(
          personName: 'Alex',
          amount: 45,
          debtId: 'alex-share',
        ),
        if (multiple)
          const ExpenseSplitShare(
            personName: 'Sam',
            amount: 20,
            debtId: 'sam-share',
          ),
      ];
      final parent = PersonalTransaction(
        id: 'purchase',
        title: 'Shared lunch',
        amount: 100,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime(2026, 10, 1),
        userId: 'alice',
        month: '2026-10',
        createdAt: DateTime(2026, 10, 1),
        split: ExpenseSplit(mode: ExpenseSplitMode.manual, shares: shares),
      );
      final debts = [
        for (final share in shares)
          PersonalTransaction(
            id: share.debtId!,
            title: '${share.personName} lunch share',
            amount: share.amount,
            type: TransactionType.expense,
            category: 'Food',
            date: parent.date,
            userId: 'alice',
            month: parent.month,
            createdAt: parent.createdAt,
            debtType: DebtType.lent,
            personName: share.personName,
            splitSourceId: parent.id,
            isSettled: settled,
            settledAmount: settled ? share.amount : 0,
          ),
      ];
      final router = GoRouter(
        initialLocation: '/personal/transactions',
        routes: [
          GoRoute(
            path: '/personal/transactions',
            builder: (_, _) =>
                const PersonalTransactionsScreen(monthKey: '2026-10'),
          ),
          GoRoute(
            path: '/personal/debts',
            builder: (_, state) => PersonalDebtsScreen(
              focusDebtId: state.uri.queryParameters['debtId'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => _OnlineConnectivity()),
            personalMonthTransactionsProvider(
              '2026-10',
            ).overrideWith((ref) => Stream.value([parent])),
            personalDebtTransactionsProvider.overrideWith(
              (ref) => Stream.value(debts),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Shared lunch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final target = shares.last;
      final action = find.text('View ${target.personName}\'s debt');
      expect(action, findsOneWidget);
      if (multiple) {
        expect(find.text('View Alex\'s debt'), findsOneWidget);
      }
      await tester.ensureVisible(action);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<PersonalDebtsScreen>(find.byType(PersonalDebtsScreen))
            .focusDebtId,
        target.debtId,
      );
      expect(find.text('Selected debt'), findsOneWidget);
      expect(find.text('${target.personName} lunch share'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('focused settled debt opens its tab and highlights its card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final debt = PersonalTransaction(
      id: 'borrowed-1',
      title: 'Borrowed for rent',
      amount: 200,
      type: TransactionType.income,
      category: 'Other',
      date: DateTime(2026, 10, 1),
      userId: 'alice',
      month: '2026-10',
      createdAt: DateTime(2026, 10, 1),
      debtType: DebtType.borrowed,
      personName: 'Alex',
      settledAmount: 200,
      isSettled: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => _OnlineConnectivity()),
          personalDebtTransactionsProvider.overrideWith(
            (ref) => Stream.value([debt]),
          ),
        ],
        child: const MaterialApp(
          home: PersonalDebtsScreen(focusDebtId: 'borrowed-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Selected debt'), findsOneWidget);
    expect(find.text('Borrowed for rent'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('debt tiles stay compact and link through transaction details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final debt = PersonalTransaction(
      id: 'borrowed-1',
      title: 'Borrowed for rent',
      amount: 200,
      type: TransactionType.income,
      category: 'Other',
      date: DateTime(2026, 10, 1),
      userId: 'alice',
      month: '2026-10',
      createdAt: DateTime(2026, 10, 1),
      debtType: DebtType.borrowed,
      personName: 'Alex',
      settledAmount: 100,
    );
    final payment = PersonalTransaction(
      id: 'payment-1',
      title: 'Settlement: Alex',
      amount: 100,
      type: TransactionType.expense,
      category: 'Other',
      date: DateTime(2026, 10, 2),
      userId: 'alice',
      month: '2026-10',
      createdAt: DateTime(2026, 10, 2),
      debtSourceId: debt.id,
    );
    final lent = PersonalTransaction(
      id: 'lent-1',
      title: 'Lent for groceries',
      amount: 120,
      type: TransactionType.expense,
      category: 'Other',
      date: DateTime(2026, 10, 1),
      userId: 'alice',
      month: '2026-10',
      createdAt: DateTime(2026, 10, 1),
      debtType: DebtType.lent,
      personName: 'Sam',
    );
    final settledLent = PersonalTransaction(
      id: 'lent-2',
      title: 'Settled grocery loan',
      amount: 80,
      type: TransactionType.expense,
      category: 'Other',
      date: DateTime(2026, 10, 1),
      userId: 'alice',
      month: '2026-10',
      createdAt: DateTime(2026, 10, 1),
      debtType: DebtType.lent,
      personName: 'Taylor',
      settledAmount: 80,
      isSettled: true,
    );
    final settledBorrowed = PersonalTransaction(
      id: 'borrowed-2',
      title: 'Repaid travel loan',
      amount: 60,
      type: TransactionType.income,
      category: 'Other',
      date: DateTime(2026, 10, 1),
      userId: 'alice',
      month: '2026-10',
      createdAt: DateTime(2026, 10, 1),
      debtType: DebtType.borrowed,
      personName: 'Jordan',
      settledAmount: 60,
      isSettled: true,
    );
    final router = GoRouter(
      initialLocation: '/personal/transactions',
      routes: [
        GoRoute(
          path: '/personal/transactions',
          builder: (_, _) =>
              const PersonalTransactionsScreen(monthKey: '2026-10'),
        ),
        GoRoute(
          path: '/personal/debts',
          builder: (_, state) => PersonalDebtsScreen(
            focusDebtId: state.uri.queryParameters['debtId'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => _OnlineConnectivity()),
          personalMonthTransactionsProvider('2026-10').overrideWith(
            (ref) => Stream.value([
              debt,
              payment,
              lent,
              settledLent,
              settledBorrowed,
            ]),
          ),
          personalDebtTransactionsProvider.overrideWith(
            (ref) => Stream.value([debt]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Borrowed'), findsNWidgets(2));
    expect(find.text('Lent'), findsNWidgets(2));
    expect(find.text('Settled'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byIcon(Icons.north_rounded),
      ),
      findsNWidgets(3),
    );
    expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
    expect(find.text('-₹200'), findsOneWidget);
    expect(find.text('-₹120'), findsOneWidget);
    expect(find.text('-₹60'), findsOneWidget);
    expect(find.text('₹80'), findsOneWidget);
    expect(find.text('View debt'), findsNothing);
    expect(find.text('Settlement: Alex'), findsNothing);
    expect(find.text('1 debt payment this month'), findsOneWidget);
    expect(find.text('View payment history in Debts'), findsOneWidget);
    await tester.tap(find.text('Borrowed for rent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Borrowed Debt'), findsOneWidget);
    await tester.tap(find.text('View debt and settlement history'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Selected debt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
