import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/presentation/debts/screens/personal_debts_screen.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/personal_transactions_screen.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';

class _OnlineConnectivity extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _OnlineConnectivity() : super(ConnectivityStatus.online);
}

void main() {
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
    expect(find.text('Debt · Borrowed'), findsNWidgets(2));
    expect(find.text('Debt · Lent'), findsNWidgets(2));
    expect(find.text('Settled'), findsNWidgets(2));
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNWidgets(3));
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
    expect(find.text('BORROWED DEBT'), findsOneWidget);
    await tester.tap(find.text('View debt and settlement history'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Selected debt'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
