import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/app/auth/models/user_model.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_model.dart';
import 'package:split_ex/modules/room/presentation/providers/bill_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/dashboard_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/expense_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/settlement_provider.dart';
import 'package:split_ex/modules/room/presentation/screens/room/room_detail_screen.dart';
import 'package:split_ex/modules/room/presentation/screens/home/room_tab.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

void main() {
  testWidgets('room entry offers joining when the user has no room', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('bob'),
          userRoomsProvider.overrideWith((ref) => Stream.value([])),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: RoomTab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  final date = DateTime(2026, 10, 12);
  RoomModel room({bool archived = false}) => RoomModel(
    id: 'home',
    name: 'Home',
    inviteCode: 'ABC123',
    adminId: 'alice',
    memberIds: const ['alice'],
    participantIds: const ['alice', 'bob'],
    createdAt: date,
    currentMonth: '2026-10',
    isArchived: archived,
  );
  final expense = ExpenseModel(
    id: 'dinner',
    title: 'Dinner',
    amount: 120,
    category: 'Food',
    date: date,
    paidBy: 'alice',
    splitType: SplitType.equal,
    splitAmong: const ['alice', 'bob'],
    createdBy: 'alice',
    createdAt: date,
    month: '2026-10',
  );
  final profiles = ['alice', 'bob']
      .map(
        (id) => UserModel(
          uid: id,
          name: id == 'alice' ? 'Alice' : 'Bob',
          email: '$id@example.test',
          isDeveloper: 'false',
          createdAt: date,
        ),
      )
      .toList();

  List<Override> overrides(
    RoomModel value, {
    List<SettlementModel> payments = const [],
    bool failPayments = false,
  }) => [
    currentUserIdProvider.overrideWithValue('bob'),
    roomStreamProvider.overrideWith((ref, id) => Stream.value(value)),
    userRoomsProvider.overrideWith((ref) => Stream.value([value])),
    monthExpensesProvider.overrideWith((ref, key) => Stream.value([expense])),
    billsStreamProvider.overrideWith((ref, key) => Stream.value([])),
    settlementsStreamProvider.overrideWith(
      (ref, id) => failPayments
          ? Stream.error(Exception('Connection lost'))
          : Stream.value(payments),
    ),
    userProfilesByIdsProvider([
      'alice',
      'bob',
    ]).overrideWith((ref) async => profiles),
  ];

  Future<void> showRoom(
    WidgetTester tester,
    RoomModel value, {
    List<SettlementModel> payments = const [],
    bool failPayments = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          value,
          payments: payments,
          failPayments: failPayments,
        ),
        child: MaterialApp(
          home: RoomDetailScreen(
            roomId: 'home',
            selectedMonthInHome: date,
            initialTabIndex: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'former member sees their old pair and can settle without a selected-room snapshot',
    (tester) async {
      await showRoom(tester, room());
      expect(find.textContaining('Former member'), findsOneWidget);
      expect(find.text('Settle Up'), findsOneWidget);
      expect(find.textContaining('Bob owes Alice'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Room Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archived history remains visible without payment or add controls',
    (tester) async {
      await showRoom(tester, room(archived: true));
      expect(find.textContaining('Archived room'), findsOneWidget);
      expect(find.textContaining('Bob owes Alice'), findsOneWidget);
      expect(find.text('Settle Up'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmed historical payment clears the pair balance and retains its details',
    (tester) async {
      await showRoom(
        tester,
        room(),
        payments: [
          SettlementModel(
            id: 'payment',
            roomId: 'home',
            fromUserId: 'bob',
            toUserId: 'alice',
            amount: 60,
            status: SettlementStatus.confirmed,
            createdAt: DateTime(2026, 11, 5),
            ledgerMonth: '2026-10',
          ),
        ],
      );
      expect(find.text('All settled'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Settle Up'), findsNothing);
      expect(find.text('View'), findsOneWidget);
    },
  );

  testWidgets('pending historical payment prevents another payment button', (
    tester,
  ) async {
    await showRoom(
      tester,
      room(),
      payments: [
        SettlementModel(
          id: 'payment',
          roomId: 'home',
          fromUserId: 'bob',
          toUserId: 'alice',
          amount: 60,
          createdAt: date,
          ledgerMonth: '2026-10',
        ),
      ],
    );
    expect(find.text('Settle Up'), findsNothing);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets(
    'failed payment history is shown as an error instead of an empty or settled balance',
    (tester) async {
      await showRoom(tester, room(), failPayments: true);
      expect(
        find.text('Unable to load balances. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('All settled'), findsNothing);
    },
  );

  test('profile requests use stable keys for equivalent participant lists', () {
    expect(
      userProfilesByIdsProvider(['bob', 'alice', 'bob']),
      equals(userProfilesByIdsProvider(['alice', 'bob'])),
    );
  });

  test(
    'monthly balances apply payments to their expense month and include former participants',
    () async {
      final container = ProviderContainer(
        overrides: overrides(
          room(),
          payments: [
            SettlementModel(
              id: 'payment',
              roomId: 'home',
              fromUserId: 'bob',
              toUserId: 'alice',
              amount: 60,
              status: SettlementStatus.confirmed,
              createdAt: DateTime(2026, 11, 5),
              ledgerMonth: '2026-10',
            ),
          ],
        ),
      );
      addTearDown(container.dispose);
      await container.read(roomStreamProvider('home').future);
      await container.read(
        monthExpensesProvider(
          const MonthRoomKey(roomId: 'home', month: '2026-10'),
        ).future,
      );
      await container.read(
        billsStreamProvider(
          const MonthBillKey(roomId: 'home', month: '2026-10'),
        ).future,
      );
      await container.read(settlementsStreamProvider('home').future);
      expect(
        container.read(
          monthNetBalancesProvider(
            const MonthBalanceKey(roomId: 'home', month: '2026-10'),
          ),
        ),
        {'alice': 0, 'bob': 0},
      );
      expect(
        container.read(
          monthParticipantIdsProvider(
            const MonthBalanceKey(roomId: 'home', month: '2026-10'),
          ),
        ),
        ['alice', 'bob'],
      );
    },
  );
}
