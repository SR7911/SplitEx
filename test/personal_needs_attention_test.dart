import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/modules/personal/domain/entities/budgets/personal_budget.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/projections/calendar/payment_calendar_event.dart';
import 'package:split_ex/modules/personal/domain/projections/dashboard/personal_attention.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_device_gateway.dart';
import 'package:split_ex/modules/personal/presentation/budgets/providers/personal_budget_providers.dart';
import 'package:split_ex/modules/personal/presentation/calendar/providers/payment_calendar_provider.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/providers/personal_attention_providers.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/widgets/personal_needs_attention_card.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_controller.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/shared/ui/theme.dart';

final _today = DateTime(2026, 12, 29);

class _Device extends Fake implements BankSmsDeviceGateway {
  @override
  bool get supported => true;

  @override
  void setEventHandler(Future<void> Function(String method)? handler) {}
}

PaymentCalendarEvent _payment(
  String id,
  DateTime date, {
  bool incoming = false,
  bool recorded = false,
}) => PaymentCalendarEvent(
  id: id,
  sourceId: id,
  title: 'Rent',
  subtitle: 'Scheduled rent',
  kind: PaymentCalendarKind.recurring,
  date: date,
  amount: 1000,
  incoming: incoming,
  recorded: recorded,
);

PersonalBudget _budget(String category, double amount) => PersonalBudget(
  id: category,
  category: category,
  budget: amount,
  userId: 'alice',
  month: '2026-12',
);

BankSmsController _sms({int reviews = 0}) =>
    BankSmsController(device: _Device())
      ..statusLoaded = true
      ..reviews = [
        for (var i = 0; i < reviews; i++)
          ParsedBankSms(
            messageId: 'message-$i',
            sender: 'VM-BANK',
            body: 'Payment',
            amountMinor: 10000,
            direction: BankSmsDirection.debit,
            date: _today,
          ),
      ];

Future<void> _openCard(
  WidgetTester tester, {
  AsyncValue<List<PaymentCalendarEvent>> payments = const AsyncData([]),
  AsyncValue<List<PersonalBudgetOverrun>> budgets = const AsyncData([]),
  BankSmsController? sms,
  bool dark = false,
  GoRouter? router,
  DateTime? selectedMonth,
}) async {
  tester.view.physicalSize = const Size(320, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = dark
      ? AppTheme.darkTheme(AppPalette.rose)
      : AppTheme.lightTheme(AppPalette.teal);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        personalAttentionTodayProvider.overrideWith((ref) => _today),
        personalAttentionPaymentsProvider.overrideWith((ref, _) => payments),
        personalAttentionBudgetsProvider.overrideWith((ref, _) => budgets),
        bankSmsControllerProvider.overrideWith((ref) => sms ?? _sms()),
      ],
      child: router == null
          ? MaterialApp(
              theme: theme,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: PersonalNeedsAttentionCard(
                    selectedMonth: selectedMonth,
                  ),
                ),
              ),
            )
          : MaterialApp.router(theme: theme, routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Gilmer',
    )..addFont(rootBundle.load('assets/fonts/Gilmer-Regular.otf'))).load();
  });

  test('due window includes today and day six across the year boundary', () {
    final today = _payment('today', DateTime(2026, 12, 29, 23));
    final lastDay = _payment('last-day', DateTime(2027, 1, 4));
    expect(
      upcomingAttentionPayments([
        lastDay,
        _payment('outside', DateTime(2027, 1, 5)),
        today,
        today,
        _payment('past', DateTime(2026, 12, 28)),
        _payment('paid', _today, recorded: true),
        _payment('income', _today, incoming: true),
      ], _today),
      [today, lastDay],
    );
  });

  test('budget overruns use paise, include zero limits and sort by excess', () {
    final result = attentionBudgetOverruns(
      [
        _budget('Food', 100),
        _budget('Travel', 50),
        _budget('Other', 0),
        _budget('Rounding', 0.3),
      ],
      {'Food': 100.01, 'Travel': 49, 'Other': 5, 'Rounding': 0.1 + 0.2},
    );
    expect(result.map((item) => item.category), ['Other', 'Food']);
    expect(result.map((item) => item.excessPaise), [500, 1]);
  });

  test('payment provider reads both months when seven days cross a year', () {
    final months = <DateTime>[];
    final container = ProviderContainer(
      overrides: [
        personalAttentionTodayProvider.overrideWith((ref) => _today),
        paymentCalendarProvider.overrideWith((ref, month) {
          months.add(month);
          return AsyncData([
            _payment(
              '$month',
              DateTime(month.year, month.month, month.month == 12 ? 31 : 2),
            ),
          ]);
        }),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(
      personalAttentionPaymentsProvider(DateTime(2026, 12)),
    );
    expect(state.requireValue, hasLength(2));
    expect(months, [DateTime(2026, 12), DateTime(2027, 1)]);
  });

  test(
    'budget provider uses current-month purchase spending, excluding debt',
    () async {
      final months = <String>[];
      final container = ProviderContainer(
        overrides: [
          personalAttentionTodayProvider.overrideWith((ref) => _today),
          personalMonthBudgetsProvider.overrideWith((ref, month) {
            months.add(month);
            return Stream.value([_budget('Food', 100)]);
          }),
          personalMonthTransactionsProvider.overrideWith(
            (ref, month) => Stream.value([
              PersonalTransaction(
                id: 'food',
                title: 'Lunch',
                amount: 125.25,
                type: TransactionType.expense,
                category: 'Food',
                date: _today,
                userId: 'alice',
                month: month,
                createdAt: _today,
              ),
              PersonalTransaction(
                id: 'lent',
                title: 'Lent',
                amount: 200,
                type: TransactionType.expense,
                category: 'Food',
                date: _today,
                userId: 'alice',
                month: month,
                createdAt: _today,
                debtType: DebtType.lent,
                personName: 'Alex',
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        personalAttentionBudgetsProvider(DateTime(2026, 12)),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(personalMonthBudgetsProvider('2026-12').future);
      await container.read(personalMonthTransactionsProvider('2026-12').future);
      expect(
        container
            .read(personalAttentionBudgetsProvider(DateTime(2026, 12)))
            .requireValue
            .single
            .excessPaise,
        2525,
      );
      expect(months, ['2026-12']);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'actionable rows fit a narrow ${dark ? 'dark' : 'light'} card',
      (tester) async {
        await _openCard(
          tester,
          dark: dark,
          payments: AsyncData([_payment('rent', _today)]),
          budgets: const AsyncData([
            PersonalBudgetOverrun(category: 'Food', excessPaise: 45000),
          ]),
          sms: _sms(reviews: 3),
        );
        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.text('1 payment due soon'), findsOneWidget);
        expect(find.text('3 messages need review'), findsOneWidget);
        expect(find.text('Food budget exceeded'), findsOneWidget);
        expect(find.text('₹450 over · Dec 2026'), findsOneWidget);
        expect(find.text('Nothing needs attention'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty data has a calm all-clear state', (tester) async {
    await _openCard(tester);
    expect(find.text('Nothing needs attention'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('historical payment checks read only the selected month', () {
    final months = <DateTime>[];
    final month = DateTime(2026, 11);
    final container = ProviderContainer(
      overrides: [
        personalAttentionTodayProvider.overrideWith((ref) => _today),
        paymentCalendarProvider.overrideWith((ref, requested) {
          months.add(requested);
          return AsyncData([
            _payment('early', DateTime(2026, 11, 1)),
            _payment('late', DateTime(2026, 11, 30)),
            _payment('other-month', DateTime(2026, 12, 1)),
            _payment('recorded', month, recorded: true),
          ]);
        }),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container
          .read(personalAttentionPaymentsProvider(month))
          .requireValue
          .map((event) => event.id),
      ['early', 'late'],
    );
    expect(months, [month]);
  });

  test('budget checks request the selected month instead of today', () async {
    final requested = <String>[];
    final month = DateTime(2026, 11);
    final container = ProviderContainer(
      overrides: [
        personalAttentionTodayProvider.overrideWith((ref) => _today),
        personalMonthBudgetsProvider.overrideWith((ref, key) {
          requested.add(key);
          return Stream.value([]);
        }),
        personalMonthDisplayTransactionsProvider.overrideWith(
          (ref, _) => const AsyncData([]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      personalAttentionBudgetsProvider(month),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(personalMonthBudgetsProvider('2026-11').future);
    expect(
      container.read(personalAttentionBudgetsProvider(month)).requireValue,
      isEmpty,
    );
    expect(requested, ['2026-11']);
  });

  testWidgets(
    'historical month hides the live inbox and uses historical labels',
    (tester) async {
      await _openCard(
        tester,
        selectedMonth: DateTime(2026, 11),
        sms: _sms(reviews: 3),
        payments: AsyncData([_payment('rent', DateTime(2026, 11, 10))]),
        budgets: const AsyncData([
          PersonalBudgetOverrun(category: 'Food', excessPaise: 45000),
        ]),
      );
      expect(find.text('1 payment unrecorded'), findsOneWidget);
      expect(find.text('₹450 over · Nov 2026'), findsOneWidget);
      expect(find.text('3 messages need review'), findsNothing);
      expect(find.textContaining('Dec 2026'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an inbox that has not loaded cannot show all clear', (
    tester,
  ) async {
    await _openCard(tester, sms: _sms()..statusLoaded = false);
    expect(find.text('Checking bank messages'), findsOneWidget);
    expect(find.text('Nothing needs attention'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and failed checks never imply all clear', (
    tester,
  ) async {
    await _openCard(
      tester,
      payments: const AsyncLoading(),
      budgets: AsyncError(StateError('offline'), StackTrace.current),
      sms: _sms(reviews: 1),
    );
    expect(find.text('Checking upcoming payments'), findsOneWidget);
    expect(find.text('Couldn’t check budget limits'), findsOneWidget);
    expect(find.text('1 message needs review'), findsOneWidget);
    expect(find.text('Nothing needs attention'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['calendar', 'sms-review', 'budgets']) {
    testWidgets(
      '$action row opens its destination with the relevant date/month',
      (tester) async {
        Object? extra;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: SingleChildScrollView(
                  child: PersonalNeedsAttentionCard(),
                ),
              ),
            ),
            GoRoute(
              path: '/personal/$action',
              builder: (_, state) {
                extra = state.extra;
                return const Scaffold(body: Text('Destination'));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        final due = DateTime(2027, 1, 2);
        await _openCard(
          tester,
          router: router,
          payments: AsyncData([_payment('rent', due)]),
          budgets: const AsyncData([
            PersonalBudgetOverrun(category: 'Food', excessPaise: 45000),
          ]),
          sms: _sms(reviews: 3),
        );
        await tester.tap(
          find.text(switch (action) {
            'calendar' => '1 payment due soon',
            'sms-review' => '3 messages need review',
            _ => 'Food budget exceeded',
          }),
        );
        await tester.pumpAndSettle();
        expect(find.text('Destination'), findsOneWidget);
        expect(
          extra,
          action == 'calendar'
              ? due
              : action == 'budgets'
              ? '2026-12'
              : null,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
