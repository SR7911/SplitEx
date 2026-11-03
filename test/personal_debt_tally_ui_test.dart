import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_tally_section.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/shared/ui/theme.dart';

PersonalTransaction _debt(String person, DebtType type, double amount) =>
    PersonalTransaction(
      id: '$person-${type.name}',
      title: type == DebtType.lent ? 'Lunch share' : 'Travel advance',
      personName: person,
      amount: amount,
      debtType: type,
      type: type == DebtType.lent
          ? TransactionType.expense
          : TransactionType.income,
      category: 'Other',
      date: DateTime(2026, 11, 1),
      userId: 'alice',
      month: '2026-11',
      createdAt: DateTime(2026, 11, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Gilmer',
    )..addFont(rootBundle.load('assets/fonts/Gilmer-Regular.otf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final sdkRoot = Platform.environment['FLUTTER_ROOT']!;
    await (FontLoader('Roboto')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$sdkRoot/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'tally card and review fit a narrow ${dark ? 'dark' : 'light'} screen with enlarged text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final debts = [
          _debt('Alex', DebtType.lent, 500),
          _debt('Alex', DebtType.borrowed, 200),
        ];
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              personalDebtTransactionsProvider.overrideWith(
                (ref) => Stream.value(debts),
              ),
            ],
            child: MaterialApp(
              theme: dark
                  ? AppTheme.darkTheme(AppPalette.rose)
                  : AppTheme.lightTheme(AppPalette.teal),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DebtTallySection(debts: debts),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tally opposite debts'), findsOneWidget);
        expect(find.text('₹200'), findsOneWidget);
        expect(find.text('₹300 left to receive'), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (const bool.fromEnvironment('CAPTURE_PREVIEW')) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage(pixelRatio: 2);
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/previews/tally_${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tester.tap(find.text('Alex'));
        await tester.pumpAndSettle();
        expect(find.text('Tally with Alex'), findsOneWidget);
        expect(find.text('Tally preview'), findsOneWidget);
        expect(find.text('Confirm Tally'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final list = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(ListView),
        );
        await tester.drag(list, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(find.text('Lunch share'), findsOneWidget);
        expect(find.text('Travel advance'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Tally with Alex'), findsNothing);
      },
    );
  }

  testWidgets(
    'multiple people remain scrollable and each opens their own preview',
    (tester) async {
      final debts = [
        for (final name in ['Alex', 'Sam', 'Taylor']) ...[
          _debt(name, DebtType.lent, 500),
          _debt(name, DebtType.borrowed, 200),
        ],
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personalDebtTransactionsProvider.overrideWith(
              (ref) => Stream.value(debts),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DebtTallySection(debts: debts),
              ),
            ),
          ),
        ),
      );
      final scroll = find.descendant(
        of: find.byType(DebtTallySection),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(-800, 0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Taylor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taylor'));
      await tester.pumpAndSettle();
      expect(find.text('Tally with Taylor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review disables confirmation when matching balances disappear', (
    tester,
  ) async {
    final debts = [
      _debt('Alex', DebtType.lent, 500),
      _debt('Alex', DebtType.borrowed, 200),
    ];
    final controller = StreamController<List<PersonalTransaction>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalDebtTransactionsProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: DebtTallySection(debts: debts)),
        ),
      ),
    );
    await tester.tap(find.text('Alex'));
    await tester.pump();
    controller.add(debts);
    await tester.pumpAndSettle();
    controller.add([]);
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListView),
      ),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(find.text('No opposing balances remain to tally.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm Tally'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
