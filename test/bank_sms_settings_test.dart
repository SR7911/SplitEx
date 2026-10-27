import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';
import 'package:split_ex/modules/personal/presentation/sms/screens/bank_sms_settings_screen.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_service.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';

class _OnlineConnectivity extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _OnlineConnectivity() : super(ConnectivityStatus.online);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> state;
  late int permissionRequests;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    permissionRequests = 0;
    state = {
      'enabled': false,
      'owner': 'test-user',
      'autoRecord': true,
      'permission': false,
      'pendingCount': 0,
      'reviews': [],
      'trustedSenders': [],
      'lastError': '',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BankSmsService.channel, (call) async {
          switch (call.method) {
            case 'status':
              return jsonEncode(state);
            case 'bindUser':
              state['owner'] = (call.arguments as Map)['userId'] ?? '';
              return null;
            case 'requestPermission':
              permissionRequests++;
              return false;
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
        .setMockMethodCallHandler(BankSmsService.channel, null),
  );
  Future<void> open(WidgetTester tester, {bool reviewOnly = false}) async {
    final service = BankSmsService();
    await service.bindUser('test-user');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityProvider.overrideWith((ref) => _OnlineConnectivity()),
          bankSmsServiceProvider.overrideWith((ref) => service),
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
}
