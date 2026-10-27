import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/shared/ui/theme.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_transfer.dart';
import 'package:split_ex/modules/personal/data/mappers/accounts/account_firestore_mapper.dart'
    show LegacyAccountSerialization, LegacyTransferSerialization;
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_account_repository.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/shared/providers/connectivity_provider.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:split_ex/modules/personal/presentation/accounts/screens/personal_accounts_screen.dart';
import 'package:split_ex/modules/personal/presentation/sms/screens/bank_sms_settings_screen.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_service.dart';

class PreviewUser extends Fake implements User { @override String get uid => 'preview'; }
class Online extends StateNotifier<ConnectivityStatus> implements ConnectivityNotifier { Online() : super(ConnectivityStatus.online); }

void main() {
  testWidgets('render revised accounts and inbox for visual inspection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 920); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    for (final font in [('Gilmer', 'assets/fonts/Gilmer-Regular.otf'), ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    final sdkRoot = Platform.environment['FLUTTER_ROOT']!;
    await (FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(File('$sdkRoot/bin/cache/artifacts/material_fonts/roboto-regular.ttf').readAsBytesSync())))).load();
    final db = FakeFirebaseFirestore();
    final accountService = FirestorePersonalAccountRepository(firestore: db);
    for (final account in const [
      PersonalAccount(id: 'bank', name: 'Salary account', type: PersonalAccountType.bank, openingBalance: 35000, last4: '1234'),
      PersonalAccount(id: 'cash', name: 'Cash', type: PersonalAccountType.cash, openingBalance: 2000),
      PersonalAccount(id: 'card', name: 'Credit card', type: PersonalAccountType.creditCard, openingBalance: -2500, last4: '8765'),
    ]) { await db.doc('users/preview/personal_accounts/${account.id}').set(account.toMap()); }
    await db.doc('users/preview/personal_transfers/one').set(PersonalTransfer(id: 'one', fromAccountId: 'bank', toAccountId: 'cash', amount: 1500, date: DateTime(2026, 10, 20), note: 'Cash withdrawal').toMap());
    await db.doc('users/preview/personal_transactions/food').set({'title': 'Lunch', 'category': 'Food', 'amount': 250, 'type': 'expense', 'date': Timestamp.fromDate(DateTime(2026, 10, 20)), 'accountId': 'bank'});
    final parser = BankSmsParser();
    final reviews = [
      parser.parse(id: 'one', sender: 'VM-TESTBK', body: 'INR 500 debited from A/c XX1234 to GROCERY STORE on 20/10/2026 UPI Ref 629300123456.', receivedAt: DateTime(2026, 10, 20))!.toMap(),
      parser.parse(id: 'two', sender: 'VM-TESTBK', body: 'INR 1200 credited to A/c XX1234 from ALEX on 20/10/2026 UPI Ref 629300123457.', receivedAt: DateTime(2026, 10, 20))!.toMap(),
    ];
    final smsService = BankSmsService()..userId = 'preview';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(BankSmsService.channel, (call) async => call.method == 'status' ? jsonEncode({'owner': 'preview', 'enabled': false, 'permission': false, 'autoRecord': true, 'pendingCount': 0, 'reviews': reviews, 'trustedSenders': [], 'lastError': ''}) : null);
    final boundary = GlobalKey();
    final appTheme = AppTheme.lightTheme(AppPalette.teal);
    Future<void> settle() async { await tester.pump(); await tester.pump(const Duration(milliseconds: 400)); }
    Future<void> open(Widget screen) async {
      await tester.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(PreviewUser())), connectivityProvider.overrideWith((ref) => Online()),
        unreadCountProvider.overrideWith((ref) => Stream.value(0)),
        personalUserIdProvider.overrideWith((ref) => const AsyncData('preview')),
        personalAccountRepositoryProvider.overrideWith((ref) => accountService),
        bankSmsServiceProvider.overrideWith((ref) => smsService),
      ], child: RepaintBoundary(key: boundary, child: MaterialApp(debugShowCheckedModeBanner: false,
        theme: appTheme.copyWith(textTheme: appTheme.textTheme.apply(fontFamilyFallback: ['Roboto'])), home: screen))));
      await settle(); await settle();
    }
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/previews/$name.png').writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();
      });
    }
    await open(const PersonalAccountsScreen()); await capture('accounts_restyled');
    await tester.tap(find.text('Add account')); await settle(); await capture('account_form_restyled');
    await tester.binding.handlePopRoute(); await settle();
    await tester.tap(find.text('Transfer money')); await settle(); await capture('transfer_form_restyled');
    await tester.binding.handlePopRoute(); await settle();
    await tester.tap(find.text('Salary account')); await settle(); await capture('account_details_restyled');
    await tester.binding.handlePopRoute(); await settle();
    await open(const BankSmsSettingsScreen(reviewOnly: true)); await capture('sms_inbox_restyled');
    await tester.pumpWidget(const SizedBox());
  });
}
