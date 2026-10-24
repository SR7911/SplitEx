import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/models/monthly_money_review.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/models/savings_goal_model.dart';
import 'package:split_ex/services/bank_sms_parser.dart';
import 'package:split_ex/services/bank_sms_repository.dart';
import 'package:split_ex/services/merchant_category_service.dart';
import 'package:split_ex/services/savings_goal_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SavingsGoalService savings;
  late MerchantCategoryService rules;
  setUp(() {
    db = FakeFirebaseFirestore();
    savings = SavingsGoalService(firestore: db);
    rules = MerchantCategoryService(firestore: db);
  });
  final now = DateTime(2026, 10, 21);
  const goal = SavingsGoal(id: 'trip', title: 'Trip', targetMinor: 100000);
  ParsedBankSms sms({
    String merchant = 'SHOP',
    String sender = 'VM-TESTBK',
    bool credit = false,
    String reference = '629300123456',
  }) => BankSmsParser().parse(
    id: reference,
    sender: sender,
    body:
        'INR 500 ${credit ? 'credited to' : 'debited from'} A/c XX1234 ${credit ? 'from' : 'to'} $merchant on 21/10/2026 UPI Ref $reference.',
    receivedAt: now,
  )!;
  test(
    'merchant matching normalizes sender and spacing but keeps exact merchant and sender boundaries',
    () async {
      await rules.save(
        'alice',
        const MerchantCategoryRule(
          sender: 'AD-TESTBK-S',
          merchant: ' SHOP ',
          category: 'Food',
        ),
      );
      expect(await rules.suggestion('alice', sms()), 'Food');
      expect(await rules.suggestion('alice', sms(merchant: 'SHOP TWO')), null);
      expect(await rules.suggestion('alice', sms(sender: 'VM-OTHERBK')), null);
      expect(await rules.suggestion('bob', sms()), null);
      expect(await rules.suggestion('alice', sms(credit: true)), null);
    },
  );
  test('paused or deleted rules no longer suggest categories', () async {
    const rule = MerchantCategoryRule(
      sender: 'TESTBK',
      merchant: 'SHOP',
      category: 'Food',
      enabled: false,
    );
    await rules.save('alice', rule);
    expect(await rules.suggestion('alice', sms()), null);
    await rules.remove('alice', rule);
    expect((await rules.watch('alice').first), isEmpty);
  });
  test(
    'remembering a reviewed category is atomic and applies only when requested for later imports',
    () async {
      final repo = BankSmsRepository(firestore: db);
      await repo.save('alice', sms(), category: 'Food', rememberCategory: true);
      expect(await rules.suggestion('alice', sms()), 'Food');
      final second = sms(reference: '629300123457');
      await repo.save('alice', second, applyMerchantRule: true);
      expect(
        (await db
                .doc(
                  'users/alice/personal_transactions/${second.transactionId}',
                )
                .get())
            .get('category'),
        'Food',
      );
      final third = sms(reference: '629300123458');
      await repo.save('alice', third, category: 'Shopping');
      expect(
        (await db
                .doc('users/alice/personal_transactions/${third.transactionId}')
                .get())
            .get('category'),
        'Shopping',
      );
    },
  );
  test(
    'failed imports do not leave a merchant rule or receipt behind',
    () async {
      final repo = BankSmsRepository(firestore: db);
      await expectLater(
        repo.save(
          'alice',
          sms(),
          category: 'Food',
          rememberCategory: true,
          accountId: 'missing',
        ),
        throwsStateError,
      );
      expect(await repo.wasRecorded('alice', sms()), false);
      expect((await rules.watch('alice').first), isEmpty);
    },
  );
  test(
    'remember category cannot turn credit reviews into automatic expense rules',
    () async {
      await BankSmsRepository(firestore: db).save(
        'alice',
        sms(credit: true),
        category: 'Salary',
        rememberCategory: true,
      );
      expect((await rules.watch('alice').first), isEmpty);
    },
  );
  test(
    'goal contributions and retry IDs update the saved amount once',
    () async {
      await savings.save('alice', goal);
      final entry = SavingsEntry(id: 'one', amountMinor: 25000, date: now);
      await savings.record('alice', goal.id, entry);
      await savings.record('alice', goal.id, entry);
      expect((await savings.watch('alice').first).single.savedMinor, 25000);
      expect((await savings.entries('alice', goal.id).first).length, 1);
      await savings.save(
        'alice',
        const SavingsGoal(id: 'trip', title: 'Renamed', targetMinor: 200000),
      );
      expect((await savings.watch('alice').first).single.savedMinor, 25000);
    },
  );
  test(
    'withdrawals, entry deletion and edits keep goal progress consistent',
    () async {
      await savings.save('alice', goal);
      await savings.record(
        'alice',
        'trip',
        SavingsEntry(id: 'add', amountMinor: 30000, date: now),
      );
      await savings.record(
        'alice',
        'trip',
        SavingsEntry(id: 'take', amountMinor: -10000, date: now),
      );
      expect((await savings.watch('alice').first).single.savedMinor, 20000);
      await expectLater(
        savings.removeEntry('alice', 'trip', 'add'),
        throwsStateError,
      );
      await savings.removeEntry('alice', 'trip', 'take');
      expect((await savings.watch('alice').first).single.savedMinor, 30000);
      await savings.removeEntry('alice', 'trip', 'add');
      expect((await savings.watch('alice').first).single.savedMinor, 0);
    },
  );
  test(
    'goals reject overdrawn, zero and missing-goal entries without financial side effects',
    () async {
      await savings.save('alice', goal);
      await expectLater(
        savings.record(
          'alice',
          'trip',
          SavingsEntry(id: 'overdraw', amountMinor: -1, date: now),
        ),
        throwsStateError,
      );
      await expectLater(
        savings.record(
          'alice',
          'trip',
          SavingsEntry(id: 'zero', amountMinor: 0, date: now),
        ),
        throwsStateError,
      );
      await expectLater(
        savings.record(
          'bob',
          'trip',
          SavingsEntry(id: 'missing', amountMinor: 1000, date: now),
        ),
        throwsStateError,
      );
      expect(
        (await db.collection('users/alice/personal_transactions').get()).docs,
        isEmpty,
      );
      expect(
        (await db.collection('users/alice/personal_transfers').get()).docs,
        isEmpty,
      );
      expect((await savings.watch('alice').first).single.savedMinor, 0);
    },
  );
  test(
    'archiving preserves progress and history but prevents new contributions',
    () async {
      await savings.save('alice', goal);
      await savings.record(
        'alice',
        'trip',
        SavingsEntry(id: 'add', amountMinor: 50000, date: now),
      );
      await savings.archive('alice', 'trip', true);
      await expectLater(
        savings.record(
          'alice',
          'trip',
          SavingsEntry(id: 'extra', amountMinor: 5000, date: now),
        ),
        throwsStateError,
      );
      expect((await savings.entries('alice', 'trip').first).length, 1);
      expect((await savings.watch('alice').first).single.savedMinor, 50000);
    },
  );
  test(
    'a goal may exceed its target while remaining and progress stay bounded',
    () async {
      await savings.save('alice', goal);
      await savings.record(
        'alice',
        'trip',
        SavingsEntry(id: 'add', amountMinor: 120000, date: now),
      );
      final result = (await savings.watch('alice').first).single;
      expect(result.saved, 1200);
      expect(result.remaining, 0);
      expect(result.progress, 1);
      expect(result.reached, true);
    },
  );
  test(
    'private rules protect merchant rules, goals and nested savings history',
    () async {
      final source = File('firestore.rules').readAsStringSync();
      final merchant = RegExp(
        r'match /merchant_category_rules/\{[^}]+\} \{[\s\S]*?\n      \}',
      ).firstMatch(source)!.group(0)!;
      final goals = RegExp(
        r'match /personal_savings_goals/\{[^}]+\} \{[\s\S]*?\n      \}',
      ).firstMatch(source)!.group(0)!;
      final secured = FakeFirebaseFirestore(
        securityRules:
            'service cloud.firestore { match /databases/{database}/documents { match /users/{userId} { $merchant $goals } } }',
      );
      secured.authObject.add({'uid': 'alice', 'token': {}});
      for (final path in [
        'merchant_category_rules/rule',
        'personal_savings_goals/goal',
        'personal_savings_goals/goal/entries/entry',
      ]) {
        await secured.doc('users/alice/$path').set({'private': true});
      }
      secured.authObject.add({'uid': 'bob', 'token': {}});
      for (final path in [
        'merchant_category_rules/rule',
        'personal_savings_goals/goal',
        'personal_savings_goals/goal/entries/entry',
      ]) {
        await expectLater(
          secured.doc('users/alice/$path').get(),
          throwsException,
        );
        await expectLater(
          secured.doc('users/alice/$path').set({'private': false}),
          throwsException,
        );
      }
    },
  );

  PersonalTransactionModel transaction(
    String id,
    double amount,
    DateTime date, {
    String category = 'Food',
    bool income = false,
  }) => PersonalTransactionModel(
    id: id,
    title: id,
    amount: amount,
    type: income ? TransactionType.income : TransactionType.expense,
    category: category,
    date: date,
    userId: 'alice',
    month: '${date.year}-${date.month}',
    createdAt: date,
  );
  MonthlyMoneyReview review({
    DateTime? month,
    DateTime? clock,
    List<PersonalTransactionModel> current = const [],
    List<PersonalTransactionModel> previous = const [],
    List<CategoryBudget> budgets = const [],
    List<PersonalTransactionModel> debts = const [],
  }) => MonthlyMoneyReview.build(
    month: month ?? now,
    now: clock ?? now,
    current: current,
    previous: previous,
    budgets: budgets,
    debts: debts,
  );
  test(
    'current-month review compares equal elapsed dates instead of the previous full month',
    () {
      final result = review(
        current: [
          transaction('today', 200, now),
          transaction('tomorrow', 999, DateTime(2026, 10, 22)),
        ],
        previous: [
          transaction('prior', 100, DateTime(2026, 9, 21)),
          transaction('late', 1000, DateTime(2026, 9, 25)),
        ],
      );
      expect(result.expenses, 200);
      expect(result.previousExpenses, 100);
      expect(result.percent, 100);
      expect(result.previousEnd, DateTime(2026, 9, 21));
    },
  );
  test(
    'completed months include their entire period and clamp short comparison months',
    () {
      final result = review(
        month: DateTime(2026, 9),
        current: [transaction('end', 200, DateTime(2026, 9, 30))],
        previous: [transaction('end', 300, DateTime(2026, 8, 31))],
      );
      expect(result.expenses, 200);
      expect(result.previousExpenses, 300);
      expect(result.inProgress, false);
      expect(
        review(
          month: DateTime(2026, 3),
          clock: DateTime(2026, 3, 31),
        ).previousEnd,
        DateTime(2026, 2, 28),
      );
    },
  );
  test(
    'uncategorized review includes only expenses and budget overspending is explicit',
    () {
      final result = review(
        current: [
          transaction('other', 250, now, category: 'Other'),
          transaction('salary', 1000, now, category: 'Other', income: true),
        ],
        budgets: [
          const CategoryBudget(
            id: 'b',
            category: 'Other',
            budget: 200,
            userId: 'alice',
            month: '2026-10',
          ),
        ],
      );
      expect(result.uncategorized.map((t) => t.id), ['other']);
      expect(result.budgets.single.remaining, -50);
      expect(result.income, 1000);
      expect(result.percent, null);
      expect(result.categories.single.current, 250);
    },
  );
  test(
    'current outstanding debt totals preserve partial settlements and write-offs',
    () {
      PersonalTransactionModel debt(
        String id,
        DebtType type, {
        bool settled = false,
      }) => PersonalTransactionModel(
        id: id,
        title: id,
        amount: 1000,
        type: TransactionType.expense,
        category: 'Other',
        date: now,
        userId: 'alice',
        month: '2026-10',
        createdAt: now,
        personName: id,
        debtType: type,
        settledAmount: 200,
        writtenOffAmount: 100,
        isSettled: settled,
      );
      final result = review(
        debts: [
          debt('lent', DebtType.lent),
          debt('borrowed', DebtType.borrowed),
          debt('closed', DebtType.lent, settled: true),
        ],
      );
      expect(result.toReceiveNow, 700);
      expect(result.toRepayNow, 700);
    },
  );
}
