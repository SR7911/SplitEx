import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';
import 'package:split_ex/modules/personal/presentation/sms/screens/bank_sms_settings_screen.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_controller.dart';
import 'package:split_ex/modules/personal/data/datasources/method_channel_bank_sms_data_source.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/presentation/accounts/providers/personal_account_providers.dart';

class _ReviewOnlyRepository extends Fake implements PersonalBankSmsRepository {
  int saves = 0;
  List<BankSmsDebtAllocation>? settledAllocations;
  List<PersonalTransaction> openDebts = [];
  int debtQueries = 0;
  ExpenseSplit? recordedSplit;
  DebtType? recordedDebtType;
  String? recordedPerson;
  String? recordedNotes;

  @override
  Future<bool> wasRecorded(String uid, ParsedBankSms sms) async => false;

  @override
  Future<List<BankSmsMatch>> possibleMatches(
    String uid,
    ParsedBankSms sms,
  ) async => [];

  @override
  Future<List<PersonalTransaction>> openDebtsForSms(
    String uid,
    ParsedBankSms sms,
  ) async {
    debtQueries++;
    return openDebts;
  }

  @override
  Future<String?> suggestedCategory(String uid, ParsedBankSms sms) async =>
      null;

  @override
  Future<BankSmsSaveResult> saveDebtSettlement(
    String uid,
    ParsedBankSms sms, {
    required List<BankSmsDebtAllocation> allocations,
    String? accountId,
    DateTime? date,
  }) async {
    settledAllocations = allocations;
    return BankSmsSaveResult.recorded;
  }

  @override
  Future<BankSmsSaveResult> save(
    String uid,
    ParsedBankSms sms, {
    String? existingId,
    String? title,
    double? amount,
    String category = 'Other',
    DateTime? date,
    BankSmsDirection? direction,
    String? accountId,
    bool matchAccount = false,
    bool applyMerchantRule = false,
    bool rememberCategory = false,
    ExpenseSplit? split,
    DebtType? debtType,
    String? personName,
    DateTime? dueDate,
    String? notes,
  }) async {
    saves++;
    recordedSplit = split;
    recordedDebtType = debtType;
    recordedPerson = personName;
    recordedNotes = notes;
    return BankSmsSaveResult.recorded;
  }
}

class _OnlineConnectivity extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _OnlineConnectivity() : super(ConnectivityStatus.online);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> state;
  late int permissionRequests;
  late int rcsAccessRequests;
  String? sharedText;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    permissionRequests = 0;
    rcsAccessRequests = 0;
    sharedText = null;
    state = {
      'enabled': false,
      'owner': 'test-user',
      'autoRecord': true,
      'permission': false,
      'rcsEnabled': false,
      'rcsPermission': false,
      'pendingCount': 0,
      'queue': <Map<String, dynamic>>[],
      'reviews': [],
      'trustedSenders': [],
      'lastError': '',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelBankSmsDataSource.channel, (
          call,
        ) async {
          switch (call.method) {
            case 'status':
              return jsonEncode(state);
            case 'bindUser':
              state['owner'] = (call.arguments as Map)['userId'] ?? '';
              return null;
            case 'requestPermission':
              permissionRequests++;
              return false;
            case 'requestRcsAccess':
              rcsAccessRequests++;
              return true;
            case 'setRcsEnabled':
              state['rcsEnabled'] = (call.arguments as Map)['enabled'];
              return null;
            case 'consumeShare':
              final value = sharedText;
              sharedText = null;
              return value;
            case 'putReview':
              (state['reviews'] as List).add(
                jsonDecode((call.arguments as Map)['json'] as String),
              );
              return null;
            case 'queue':
              return jsonEncode(state['queue']);
            case 'acknowledge':
              (state['queue'] as List).removeWhere(
                (item) => item['id'] == (call.arguments as Map)['id'],
              );
              return null;
            case 'configure':
              expect((call.arguments as Map)['userId'], 'test-user');
              state['enabled'] = (call.arguments as Map)['enabled'];
              state['autoRecord'] = (call.arguments as Map)['autoRecord'];
              return null;
            case 'deleteReview':
              (state['reviews'] as List).removeWhere(
                (entry) => entry['messageId'] == (call.arguments as Map)['id'],
              );
              return null;
            default:
              return null;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelBankSmsDataSource.channel, null),
  );
  Future<void> open(
    WidgetTester tester, {
    bool reviewOnly = false,
    _ReviewOnlyRepository? repository,
  }) async {
    final service = BankSmsController(
      device: MethodChannelBankSmsDataSource(),
      repository: repository,
    );
    await service.bindUser('test-user');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => _OnlineConnectivity()),
          bankSmsControllerProvider.overrideWith((ref) => service),
          if (repository != null)
            bankSmsRepositoryProvider.overrideWith((ref) => repository),
          personalAccountsProvider.overrideWith((ref) => Stream.value([])),
          unreadCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(home: BankSmsSettingsScreen(reviewOnly: reviewOnly)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'personal inbox shows review count and dismisses messages without enabling capture',
    (tester) async {
      final sms = BankSmsParser().parse(
        id: 'review',
        sender: 'VM-TESTBK',
        body: 'INR 500 debited from A/c XX1234 to SHOP UPI Ref 629300123456.',
        receivedAt: DateTime.now(),
      )!;
      state['reviews'] = [sms.toMap()];
      await open(tester, reviewOnly: true);
      expect(find.text('SMS Review Inbox'), findsOneWidget);
      expect(find.text('Capture new bank SMS'), findsNothing);
      expect(find.text('Review Transactions (1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Review Transactions (0)'), findsOneWidget);
      expect(state['enabled'], false);
      expect(permissionRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final sharing in [true, false]) {
    testWidgets(
      'SMS review records ${sharing ? 'a shared expense' : 'money lent'} without editing again',
      (tester) async {
        final sms = BankSmsParser().parse(
          id: 'shared-review',
          sender: 'VM-TESTBK',
          body: 'INR 100 debited from A/c XX1234 to SHOP UPI Ref 629300123456.',
          receivedAt: DateTime.now(),
        )!;
        state['reviews'] = [sms.toMap()];
        final repository = _ReviewOnlyRepository();
        await open(tester, reviewOnly: true, repository: repository);
        await tester.tap(find.text(sms.title).first);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        final toggle = find.widgetWithText(
          SwitchListTile,
          sharing ? 'Split this expense' : 'Involves someone else?',
        );
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        if (sharing) {
          await tester.ensureVisible(find.text('Manual'));
          await tester.tap(find.text('Manual'));
          await tester.pumpAndSettle();
          final person = find.widgetWithText(TextField, 'Person 1');
          await tester.ensureVisible(person);
          await tester.enterText(person, 'Alex');
          final share = find.widgetWithText(TextField, 'Share');
          await tester.ensureVisible(share);
          await tester.enterText(share, '45');
        } else {
          final person = find.widgetWithText(TextField, 'Person’s name');
          await tester.ensureVisible(person);
          await tester.enterText(person, 'Alex');
        }
        final notes = find.widgetWithText(TextField, 'Notes (optional)');
        await tester.ensureVisible(notes);
        await tester.enterText(notes, 'Lunch');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Record Transaction'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record Transaction'));
        await tester.pumpAndSettle();
        expect(repository.saves, 1);
        expect(repository.recordedNotes, 'Lunch');
        if (sharing) {
          expect(repository.recordedSplit!.shares.single.personName, 'Alex');
          expect(repository.recordedSplit!.shares.single.amount, 45);
        } else {
          expect(repository.recordedDebtType, DebtType.lent);
          expect(repository.recordedPerson, 'Alex');
        }
        expect(state['reviews'], isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reviewed bank payment follows selected debt priority', (
    tester,
  ) async {
    final now = DateTime.now();
    final sms = BankSmsParser().parse(
      id: 'debt-payment-review',
      sender: 'VM-TESTBK',
      body: 'INR 200 credited to A/c XX1234 from ALEX UPI Ref 629300123456.',
      receivedAt: now,
    )!;
    state['reviews'] = [sms.toMap()];
    final repository = _ReviewOnlyRepository()
      ..openDebts = [
        PersonalTransaction(
          id: 'lent-debt-1',
          title: 'Loan to Alex',
          amount: 500,
          type: TransactionType.expense,
          category: 'Debt',
          date: now.subtract(const Duration(days: 1)),
          userId: 'test-user',
          month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          createdAt: now,
          debtType: DebtType.lent,
          personName: 'Alex',
        ),
        PersonalTransaction(
          id: 'lent-debt-2',
          title: 'Small loan to Alex',
          amount: 100,
          type: TransactionType.expense,
          category: 'Debt',
          date: now.subtract(const Duration(days: 2)),
          userId: 'test-user',
          month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          createdAt: now,
          debtType: DebtType.lent,
          personName: 'Alex',
        ),
      ];
    await open(tester, reviewOnly: true, repository: repository);
    await tester.tap(find.text(sms.title).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Review bank payment'), findsOneWidget);
    expect(repository.debtQueries, 1);
    expect(find.text('Apply payment to an existing debt'), findsOneWidget);
    await tester.ensureVisible(find.text('Apply payment to an existing debt'));
    await tester.pump();
    await tester.tap(find.text('Apply payment to an existing debt'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.settledAllocations, isNull);
    final debtCheckbox = find.descendant(
      of: find.byKey(const ValueKey('sms-debt-lent-debt-1')),
      matching: find.byType(CheckboxListTile),
    );
    await tester.ensureVisible(debtCheckbox);
    await tester.tap(debtCheckbox);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('₹300.00 left'), findsOneWidget);
    final secondCheckbox = find.descendant(
      of: find.byKey(const ValueKey('sms-debt-lent-debt-2')),
      matching: find.byType(CheckboxListTile),
    );
    await tester.ensureVisible(secondCheckbox);
    await tester.tap(secondCheckbox);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Payment is fully used. Deselect extra debts.'),
      findsOneWidget,
    );
    final moveEarlier = find.byKey(const ValueKey('sms-debt-up-lent-debt-2'));
    await tester.ensureVisible(moveEarlier);
    await tester.tap(moveEarlier);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Apply ₹100.00 · ₹0.00 left'), findsOneWidget);
    expect(find.textContaining('Apply ₹100.00 · ₹400.00 left'), findsOneWidget);
    await tester.ensureVisible(find.text('Apply SMS Payment to Debt'));
    await tester.tap(find.text('Apply SMS Payment to Debt'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.settledAllocations?.map((item) => item.debtId), [
      'lent-debt-2',
      'lent-debt-1',
    ]);
    expect(repository.settledAllocations?.map((item) => item.amountMinor), [
      10000,
      10000,
    ]);
    expect(repository.saves, 0);
    expect(state['reviews'], isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'cancelled disclosure never requests SMS permission or enables capture',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Capture new bank SMS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Record payments from bank SMS?'), findsOneWidget);
      expect(permissionRequests, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(permissionRequests, 0);
      expect(state['enabled'], false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('denied runtime SMS permission leaves capture off', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Capture new bank SMS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(permissionRequests, 1);
    expect(state['enabled'], false);
    expect(
      find.text('SMS permission was not granted. Capture remains off.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'automatic recording can be disabled without enabling SMS capture',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Auto-record trusted expenses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(state['autoRecord'], false);
      expect(state['enabled'], false);
      expect(permissionRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('shared RCS payment is kept for review after a cold app launch', () async {
    sharedText =
        'INR 500 debited from A/c XX1234 to SHOP UPI Ref 629300123456.';
    final service = BankSmsController(device: MethodChannelBankSmsDataSource());
    await service.bindUser('test-user');
    expect(service.sharedImportCount, 1);
    expect(service.reviews, hasLength(1));
    expect(service.reviews.single.source, 'shared');
    expect(
      service.reviews.single.reviewReasons,
      contains(
        'Shared from another app. Verify the sender and payment details before recording.',
      ),
    );
    expect(sharedText, isNull);
    service.dispose();
  });

  test(
    'Google Messages alert stays in review even for a trusted sender',
    () async {
      state['rcsEnabled'] = true;
      state['rcsPermission'] = true;
      state['trustedSenders'] = ['RCS-CANARABANK'];
      state['queue'] = [
        {
          'id': 'rcs-alert',
          'owner': 'test-user',
          'source': 'rcs',
          'sender': 'RCS-CANARABANK',
          'body':
              'INR 500 debited from A/c XX1234 to SHOP UPI Ref 629300123456.',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ];
      final repository = _ReviewOnlyRepository();
      final service = BankSmsController(
        repository: repository,
        device: MethodChannelBankSmsDataSource(),
      );
      await service.bindUser('test-user');
      await service.process();
      expect(service.error, isNull);
      expect(state['reviews'], hasLength(1));
      expect(repository.saves, 0);
      expect(service.reviews, hasLength(1));
      expect(service.reviews.single.source, 'rcs');
      expect(
        service.reviews.single.reviewReasons,
        contains(
          'Captured from a Google Messages notification. Verify the sender and payment details before recording.',
        ),
      );
      expect(state['queue'], isEmpty);
      service.dispose();
    },
  );

  testWidgets('RCS notification access is requested only after consent', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Review Google Messages alerts'));
    await tester.tap(find.text('Review Google Messages alerts'));
    await tester.pump();
    expect(find.text('Review Google Messages payment alerts?'), findsOneWidget);
    expect(rcsAccessRequests, 0);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(rcsAccessRequests, 1);
    expect(state['rcsEnabled'], true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
