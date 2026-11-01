import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/presentation/accounts/providers/personal_account_providers.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/add_personal_transaction_screen.dart';
import 'package:split_ex/modules/personal/presentation/transactions/widgets/expense_split_editor.dart';

void main() {
  testWidgets(
    'manual split rejects over-allocation and shows the remaining own share',
    (tester) async {
      final key = GlobalKey<ExpenseSplitEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpenseSplitEditor(
                key: key,
                totalText: '100',
                initialSplit: const ExpenseSplit(
                  mode: ExpenseSplitMode.manual,
                  shares: [
                    ExpenseSplitShare(personName: 'Alex', amount: 60),
                    ExpenseSplitShare(personName: 'Sam', amount: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Over total'), findsOneWidget);
      expect(() => key.currentState!.buildSplit(), throwsStateError);

      await tester.enterText(find.byType(TextField).at(3), '30');
      await tester.pump();
      expect(find.text('Over total'), findsNothing);
      expect(find.text('Your share: ₹10.00'), findsOneWidget);
      expect(key.currentState!.buildSplit().ownShareCents(100), 1000);
    },
  );

  testWidgets(
    'add expense sheet keeps account and split fields usable on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personalAccountsProvider.overrideWith(
              (ref) => Stream.value(<PersonalAccount>[]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAddPersonalTransactionSheet(context),
                  child: const Text('Open expense'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open expense'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Account (optional)'), findsOneWidget);
      await tester.ensureVisible(find.text('Split with people'));
      await tester.tap(find.text('Split with people'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Split this expense'));
      expect(find.text('Split this expense'), findsOneWidget);
      expect(find.text('Repayment date (optional)'), findsOneWidget);
      await tester.tap(find.text('Manual'));
      await tester.pump();
      expect(find.text('Share'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
