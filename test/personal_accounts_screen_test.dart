import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/models/personal_account_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/connectivity_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/personal_account_provider.dart';
import 'package:split_ex/screens/personal/personal_accounts_screen.dart';
import 'package:split_ex/services/personal_account_service.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _Online extends StateNotifier<ConnectivityStatus>
    implements ConnectivityNotifier {
  _Online() : super(ConnectivityStatus.online);
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
  });
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_User())),
          connectivityProvider.overrideWith((ref) => _Online()),
          unreadCountProvider.overrideWith((ref) => Stream.value(0)),
          personalAccountServiceProvider.overrideWith(
            (ref) => PersonalAccountService(firestore: db),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppPalette.teal),
          home: const PersonalAccountsScreen(),
        ),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  testWidgets('account form creates an account with an opening balance', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Add account').first);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Account name'),
      'Daily bank',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Opening balance'),
      '1000',
    );
    await tester.ensureVisible(find.text('Save account'));
    await tester.tap(find.text('Save account'));
    await settle(tester);
    await settle(tester);
    final data = (await db.collection('users/alice/personal_accounts').get())
        .docs
        .single
        .data();
    expect(data['name'], 'Daily bank');
    expect(data['openingBalance'], 1000);
    expect(find.text('Daily bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'transfer form requires different accounts and creates no expense',
    (tester) async {
      for (final a in const [
        PersonalAccount(
          id: 'bank',
          name: 'Bank',
          type: PersonalAccountType.bank,
          openingBalance: 1000,
        ),
        PersonalAccount(
          id: 'cash',
          name: 'Cash',
          type: PersonalAccountType.cash,
        ),
      ]) {
        await db.doc('users/alice/personal_accounts/${a.id}').set(a.toMap());
      }
      await open(tester);
      await tester.tap(find.text('Transfer money'));
      await settle(tester);
      await tester.tap(find.text('Save transfer'));
      await settle(tester);
      expect(
        find.text('Choose different accounts and enter a positive amount.'),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'From account'),
      );
      await settle(tester);
      await tester.tap(find.text('Bank').last);
      await settle(tester);
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'To account'),
      );
      await settle(tester);
      await tester.tap(find.text('Cash').last);
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '250');
      await tester.ensureVisible(find.text('Save transfer'));
      await tester.tap(find.text('Save transfer'));
      await settle(tester);
      await settle(tester);
      expect(
        (await db.collection('users/alice/personal_transfers').get())
            .docs
            .single
            .data()['amount'],
        250,
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
