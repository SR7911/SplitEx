import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/models/monthly_money_review.dart';
import 'package:split_ex/models/personal_account_model.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/models/savings_goal_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/connectivity_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/personal_account_provider.dart';
import 'package:split_ex/providers/monthly_money_review_provider.dart';
import 'package:split_ex/screens/personal/monthly_money_review_screen.dart';
import 'package:split_ex/screens/personal/merchant_category_rules_screen.dart';
import 'package:split_ex/screens/personal/savings_goals_screen.dart';
import 'package:split_ex/screens/personal/personal_tools_section.dart';
import 'package:split_ex/screens/settings/bank_sms_settings_screen.dart';
import 'package:split_ex/services/merchant_category_service.dart';
import 'package:split_ex/services/savings_goal_service.dart';
import 'package:split_ex/services/bank_sms_repository.dart';
import 'package:split_ex/services/bank_sms_parser.dart';
import 'package:split_ex/services/bank_sms_service.dart';

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
  late SavingsGoalService savings;
  late MerchantCategoryService rules;
  late BankSmsRepository repo;
  late BankSmsService smsService;
  late Map<String, dynamic> native;
  final previewBoundary = GlobalKey();
  final now = DateTime(2026, 10, 21);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    savings = SavingsGoalService(firestore: db);
    rules = MerchantCategoryService(firestore: db);
    repo = BankSmsRepository(firestore: db);
    smsService = BankSmsService(repository: repo)..userId = 'alice';
    native = {
      'owner': 'alice',
      'enabled': false,
      'autoRecord': true,
      'permission': false,
      'pendingCount': 0,
      'reviews': [],
      'trustedSenders': [],
      'lastError': '',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BankSmsService.channel, (call) async {
          if (call.method == 'status') return jsonEncode(native);
          if (call.method == 'deleteReview') {
            (native['reviews'] as List).removeWhere(
              (e) => e['messageId'] == (call.arguments as Map)['id'],
            );
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BankSmsService.channel, null),
  );
  PersonalTransactionModel entry(
    String id,
    double amount,
    String category,
    DateTime date,
  ) => PersonalTransactionModel(
    id: id,
    title: id,
    amount: amount,
    type: TransactionType.expense,
    category: category,
    date: date,
    userId: 'alice',
    month: '2026-10',
    createdAt: date,
  );
  MonthlyMoneyReview fixture(DateTime month) => MonthlyMoneyReview.build(
    month: month,
    now: now,
    current: [
      entry(
        'Groceries',
        2800,
        'Groceries',
        DateTime(month.year, month.month, 10),
      ),
      entry(
        'Needs a category',
        250,
        'Other',
        DateTime(month.year, month.month, 15),
      ),
    ],
    previous: [
      entry(
        'Prior groceries',
        2200,
        'Groceries',
        DateTime(month.year, month.month - 1, 10),
      ),
    ],
    budgets: [
      const CategoryBudget(
        id: 'food',
        category: 'Groceries',
        budget: 2500,
        userId: 'alice',
        month: '2026-10',
      ),
    ],
    debts: [],
  );
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    GoRouter? router,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(360, 1100);
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
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root != null) {
        await (FontLoader('Roboto')..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    '$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
                  ).readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
    }
    final base = brightness == Brightness.dark
        ? AppTheme.darkTheme(AppPalette.teal)
        : AppTheme.lightTheme(AppPalette.teal);
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: ['Roboto']),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_User())),
          connectivityProvider.overrideWith((ref) => _Online()),
          unreadCountProvider.overrideWith((ref) => Stream.value(0)),
          personalAccountsProvider.overrideWith(
            (ref) => Stream.value(<PersonalAccount>[]),
          ),
          savingsGoalServiceProvider.overrideWith((ref) => savings),
          merchantCategoryServiceProvider.overrideWith((ref) => rules),
          bankSmsServiceProvider.overrideWith((ref) => smsService),
          bankSmsRepositoryProvider.overrideWith((ref) => repo),
          monthlyMoneyReviewProvider.overrideWith(
            (ref, month) => AsyncData(fixture(month)),
          ),
        ],
        child: RepaintBoundary(
          key: previewBoundary,
          child: router == null
              ? MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: theme,
                  home: screen,
                )
              : MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: theme,
                  routerConfig: router,
                ),
        ),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEW')) return;
    await tester.runAsync(() async {
      final image =
          await (previewBoundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/previews').create(recursive: true);
      await File(
        'build/previews/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Personal entry points open the selected month review and savings goals',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: PersonalToolsSection(monthKey: '2026-09')),
          ),
          GoRoute(
            path: '/personal/money-review',
            builder: (_, state) =>
                Scaffold(body: Text('Review month: ${state.extra}')),
          ),
          GoRoute(
            path: '/personal/goals',
            builder: (_, _) => const Scaffold(body: Text('Goals destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await open(tester, const SizedBox(), router: router);
      await capture(tester, 'personal_tools_review_goals');
      await tester.tap(find.text('Monthly Money Review'));
      await settle(tester);
      expect(find.text('Review month: 2026-09'), findsOneWidget);
      router.go('/');
      await settle(tester);
      await settle(tester);
      await tester.tap(find.text('Savings Goals'));
      await settle(tester);
      await settle(tester);
      expect(find.text('Goals destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'monthly review opens uncategorized entries at narrow phone width',
    (tester) async {
      await open(tester, MonthlyMoneyReviewScreen(initialMonth: now));
      await capture(tester, 'monthly_money_review_light');
      await tester.ensureVisible(find.text('1 uncategorized expense'));
      await tester.tap(find.text('1 uncategorized expense'));
      await settle(tester);
      expect(find.text('Needs a category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('savings goal creation saves the target and no expense', (
    tester,
  ) async {
    await open(tester, const SavingsGoalsScreen());
    await tester.tap(find.byTooltip('Add savings goal'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Goal name'), 'Trip');
    await tester.enterText(
      find.widgetWithText(TextField, 'Target amount'),
      '50000',
    );
    await tester.ensureVisible(find.text('Save goal'));
    await tester.tap(find.text('Save goal'));
    await settle(tester);
    await settle(tester);
    final goal = (await savings.watch('alice').first).single;
    expect(goal.title, 'Trip');
    expect(goal.targetMinor, 5000000);
    expect(goal.savedMinor, 0);
    expect(
      (await db.collection('users/alice/personal_transactions').get()).docs,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'savings_goals_light');
  });
  testWidgets(
    'contribution and withdrawal sheets update progress and keep expenses unchanged',
    (tester) async {
      await savings.save(
        'alice',
        const SavingsGoal(id: 'trip', title: 'Trip', targetMinor: 500000),
      );
      await open(
        tester,
        const SavingsGoalDetailScreen(goalId: 'trip'),
        brightness: Brightness.dark,
      );
      await tester.tap(find.text('Add savings'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '200');
      await tester.ensureVisible(find.text('Record savings'));
      await tester.tap(find.text('Record savings'));
      await settle(tester);
      await settle(tester);
      expect((await savings.watch('alice').first).single.savedMinor, 20000);
      await tester.tap(find.text('Withdraw'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '50');
      await tester.ensureVisible(find.text('Record withdrawal'));
      await tester.tap(find.text('Record withdrawal'));
      await settle(tester);
      await settle(tester);
      expect((await savings.watch('alice').first).single.savedMinor, 15000);
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'savings_goal_detail_dark');
    },
  );
  testWidgets('merchant rule manager can pause an existing rule', (
    tester,
  ) async {
    await rules.save(
      'alice',
      const MerchantCategoryRule(
        sender: 'TESTBK',
        merchant: 'SHOP',
        category: 'Food',
      ),
    );
    await open(tester, const MerchantCategoryRulesScreen());
    await capture(tester, 'merchant_category_rules_light');
    await tester.tap(find.text('SHOP'));
    await settle(tester);
    await tester.tap(find.text('Rule enabled'));
    await settle(tester);
    await tester.ensureVisible(find.text('Save rule'));
    await tester.tap(find.text('Save rule'));
    await settle(tester);
    await settle(tester);
    expect((await rules.watch('alice').first).single.enabled, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'SMS review remembers a category only after recording the payment',
    (tester) async {
      final sms = BankSmsParser().parse(
        id: 'one',
        sender: 'VM-TESTBK',
        body:
            'INR 500 debited from A/c XX1234 to SHOP on 21/10/2026 UPI Ref 629300123456.',
        receivedAt: now,
      )!;
      native['reviews'] = [sms.toMap()];
      await open(tester, const BankSmsSettingsScreen(reviewOnly: true));
      await tester.tap(find.text('SHOP'));
      await settle(tester);
      await settle(tester);
      await tester.ensureVisible(
        find.widgetWithText(DropdownButtonFormField<String>, 'Category'),
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Category'),
      );
      await settle(tester);
      await tester.tap(find.text('Food').last);
      await settle(tester);
      await tester.ensureVisible(
        find.text('Use this category for future payments'),
      );
      await tester.tap(find.text('Use this category for future payments'));
      await settle(tester);
      expect((await rules.watch('alice').first), isEmpty);
      await tester.ensureVisible(find.text('Record Transaction'));
      await tester.tap(find.text('Record Transaction'));
      await settle(tester);
      await settle(tester);
      expect((await rules.watch('alice').first).single.category, 'Food');
      expect(
        (await db
                .doc('users/alice/personal_transactions/${sms.transactionId}')
                .get())
            .get('category'),
        'Food',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
