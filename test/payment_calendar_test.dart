import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/shared/ui/theme.dart';
import 'package:split_ex/modules/personal/domain/projections/calendar/payment_calendar_event.dart';
import 'support/personal_transaction_fixture.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_entry.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_payment.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';
import 'package:split_ex/modules/personal/presentation/calendar/providers/payment_calendar_provider.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:split_ex/modules/personal/presentation/calendar/screens/payment_calendar_screen.dart';

class _Online extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _Online() : super(ConnectivityStatus.online);
}

final _now = DateTime(2026, 10, 20);
PersonalLoan _loan({
  String id = 'loan',
  PersonalLoanType type = PersonalLoanType.borrowed,
  String? recurringId,
  PersonalLoanStatus status = PersonalLoanStatus.active,
}) => PersonalLoan(
  id: id,
  userId: 'alice',
  title: 'Education loan',
  loanType: type,
  principal: 12000,
  annualInterestRate: 0,
  tenureMonths: 12,
  startDate: DateTime(2026, 9, 1),
  emiStartDate: DateTime(2026, 10, 5),
  emiDueDay: 5,
  status: status,
  createdAt: DateTime(2026, 9, 1),
  recurringId: recurringId,
);
PersonalRecurringEntry _recurring({
  String id = 'rent',
  PersonalRecurringFrequency frequency = PersonalRecurringFrequency.monthly,
  int day = 25,
  DateTime? lastRun,
  DateTime? end,
  DateTime? created,
  bool active = true,
}) => PersonalRecurringEntry(
  id: id,
  title: 'Apartment rent',
  amount: 12000,
  category: 'Rent',
  type: TransactionType.expense,
  frequency: frequency,
  dayOfMonth: day,
  active: active,
  userId: 'alice',
  lastRunDate: lastRun,
  endDate: end,
  createdAt: created ?? DateTime(2026, 9, 1),
);
PersonalTransactionModel _debt({
  DateTime? due,
  bool settled = false,
  double paid = 250,
  DebtType type = DebtType.lent,
}) => PersonalTransactionModel(
  id: 'debt',
  title: 'Weekend trip',
  amount: 1000,
  type: TransactionType.expense,
  category: 'Other',
  date: DateTime(2026, 10, 1),
  userId: 'alice',
  month: '2026-10',
  createdAt: DateTime(2026, 10, 1),
  personName: 'Alex',
  debtType: type,
  dueDate: due,
  settledAmount: paid,
  isSettled: settled,
);
List<PaymentCalendarEvent> _build({
  DateTime? month,
  List<PersonalLoan> loans = const [],
  Map<String, List<PersonalLoanPayment>> payments = const {},
  List<PersonalRecurringEntry> recurring = const [],
  List<PersonalTransactionModel> debts = const [],
}) => buildPaymentCalendar(
  month: month ?? _now,
  loans: loans,
  payments: payments,
  recurring: recurring,
  debts: debts,
  now: _now,
);

void main() {
  test('monthly due day clamps to February including leap years', () {
    final r = _recurring(day: 31, created: DateTime(2023));
    expect(
      _build(month: DateTime(2027, 2), recurring: [r]).single.date,
      DateTime(2027, 2, 28),
    );
    expect(
      _build(month: DateTime(2028, 2), recurring: [r]).single.date,
      DateTime(2028, 2, 29),
    );
  });
  test(
    'weekly dates follow the seven-day anchor and respect start and end dates',
    () {
      final r = _recurring(
        frequency: PersonalRecurringFrequency.weekly,
        lastRun: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 20),
      );
      final entries = _build(recurring: [r]);
      expect(entries.map((e) => e.date.day), [5, 12, 19]);
      expect(entries.map((e) => e.recorded), [true, false, false]);
    },
  );
  test(
    'inactive schedules, dates before creation and after end are excluded',
    () {
      expect(_build(recurring: [_recurring(active: false)]), isEmpty);
      expect(
        _build(recurring: [_recurring(created: DateTime(2026, 11))]),
        isEmpty,
      );
      expect(
        _build(recurring: [_recurring(end: DateTime(2026, 10, 10))]),
        isEmpty,
      );
    },
  );
  test('loan-linked recurring entries appear once as EMI', () {
    final events = _build(
      loans: [_loan(recurringId: 'rent')],
      recurring: [_recurring()],
    );
    expect(events.length, 1);
    expect(events.single.kind, PaymentCalendarKind.emi);
  });
  test(
    'late EMI logs mark the matching installment recorded without shifting to next month',
    () {
      final events = _build(
        loans: [_loan()],
        payments: {
          'loan': [
            PersonalLoanPayment(
              id: 'paid',
              amount: 1000,
              principalComponent: 1000,
              interestComponent: 0,
              remainingPrincipalAfter: 11000,
              date: DateTime(2026, 10, 9),
              type: PersonalLoanPaymentType.emi,
            ),
          ],
        },
      );
      expect(events.single.date, DateTime(2026, 10, 5));
      expect(events.single.recorded, true);
    },
  );
  test('closed loans do not create future unpaid installments', () {
    expect(
      _build(loans: [_loan(status: PersonalLoanStatus.foreclosed)]),
      isEmpty,
    );
  });
  test(
    'partial debt uses remaining balance, lent is incoming, no date is excluded',
    () {
      final events = _build(
        debts: [
          _debt(due: DateTime(2026, 10, 23)),
          _debt(),
        ],
      );
      expect(events.length, 1);
      expect(events.single.amount, 750);
      expect(events.single.incoming, true);
      expect(events.single.status(_now), PaymentCalendarStatus.scheduled);
    },
  );
  test('debt dates persist and missing fields remain backward compatible', () {
    final original = _debt(due: DateTime(2026, 10, 23));
    expect(
      PersonalTransactionModel.fromMap({
        ...original.toMap(),
        'createdAt': Timestamp.fromDate(_now),
      }, original.id).dueDate,
      original.dueDate,
    );
    expect(
      PersonalTransactionModel.fromMap({'amount': 100}, 'legacy').dueDate,
      null,
    );
  });
  test('recorded entries are not overdue, today remains scheduled', () {
    final overdue = _build(debts: [_debt(due: DateTime(2026, 10, 19))]).single;
    expect(overdue.status(_now), PaymentCalendarStatus.overdue);
    expect(
      _build(debts: [_debt(due: _now)]).single.status(_now),
      PaymentCalendarStatus.scheduled,
    );
    expect(
      _build(
        debts: [_debt(due: DateTime(2026, 10, 19), settled: true)],
      ).single.status(_now),
      PaymentCalendarStatus.recorded,
    );
  });

  final boundary = GlobalKey();
  List<PaymentCalendarEvent> fixtures(DateTime month) => _build(
    month: month,
    loans: [_loan()],
    recurring: [
      _recurring(),
      _recurring(id: 'phone', day: 20),
    ],
    debts: [_debt(due: DateTime(2026, 10, 23))],
  );
  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double width = 430,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
      for (final font in [
        ('Gilmer', 'assets/fonts/Gilmer-Regular.otf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot != null) {
        final font = File(
          '$flutterRoot/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        );
        if (font.existsSync()) {
          await (FontLoader('Roboto')..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync())),
              ))
              .load();
        }
      }
    }
    final theme = brightness == Brightness.light
        ? AppTheme.lightTheme(AppPalette.teal)
        : AppTheme.darkTheme(AppPalette.teal);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => _Online()),
          unreadCountProvider.overrideWith((ref) => Stream.value(0)),
          paymentCalendarProvider.overrideWith(
            (ref, month) => AsyncData(fixtures(month)),
          ),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(
                fontFamilyFallback: const ['Roboto'],
              ),
            ),
            home: PaymentCalendarScreen(initialDate: _now),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets(
    'calendar dates select a daily agenda and month controls cross year boundaries',
    (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('calendar-2026-10-23')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-2026-10-23')));
      await _settle(tester);
      await tester.ensureVisible(find.text('Weekend trip'));
      expect(find.text('Weekend trip'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Next month'));
      await _settle(tester);
      expect(find.text('November'), findsOneWidget);
      await tester.tap(find.byTooltip('Next month'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Next month'));
      await _settle(tester);
      expect(find.text('January'), findsOneWidget);
      expect(find.text('2027'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'calendar renders ${brightness.name} at phone width without overflow',
      (tester) async {
        await open(tester, brightness: brightness, width: 360);
        if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/previews').create(recursive: true);
            await File(
              'build/previews/payment_calendar_${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await _settle(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

// The existing app header runs a repeating connectivity animation even online.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
