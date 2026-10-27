import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_loan_repository.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_payment.dart';
import 'package:split_ex/modules/personal/domain/use_cases/loans/record_personal_emi_payment.dart';
import 'package:split_ex/modules/personal/domain/use_cases/loans/record_missed_personal_emis.dart';
import 'package:split_ex/modules/personal/domain/use_cases/loans/record_personal_partial_payment.dart';
import 'package:split_ex/modules/personal/domain/use_cases/loans/foreclose_personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_changes.dart';
import 'package:split_ex/modules/personal/domain/use_cases/loans/save_personal_loan.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestorePersonalLoanRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    repository = FirestorePersonalLoanRepository(firestore: db);
  });

  test(
    'loan read preserves ordering, document IDs and EMI calculation',
    () async {
      final loans = db.collection('users').doc('alice').collection('loans');
      await loans.doc('first').set({
        'userId': 'alice',
        'title': 'First loan',
        'loanType': 'borrowed',
        'principal': 12000,
        'annualInterestRate': 12,
        'tenureMonths': 12,
        'startDate': Timestamp.fromDate(DateTime(2026, 1, 5)),
        'emiDueDay': 5,
        'status': 'active',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 5)),
        'recurringId': 'linked',
        'processingFee': 50,
        'insuranceFee': 30,
        'otherCharges': 20,
        'gstOnFees': 9,
      });
      await loans.doc('second').set({
        'title': 'Second loan',
        'principal': 5000,
        'createdAt': Timestamp.fromDate(DateTime(2026, 2)),
      });

      final results = await repository.loans('alice').first;
      expect(results.map((loan) => loan.id), ['second', 'first']);
      expect(results.first.loanType, PersonalLoanType.borrowed);
      expect(results.first.status, PersonalLoanStatus.active);
      expect(results.last.recurringId, 'linked');
      expect(results.last.baseEmi, closeTo(1066.1854641401003, 0.000001));
      expect(results.last.effectiveEmiStart, DateTime(2026, 2, 5));
      expect(results.last.endDate, DateTime(2027, 1, 5));
      expect(results.last.totalCharges, 109);
      expect(results.last.netDisbursed, 11891);
      expect(await repository.loans('bob').first, isEmpty);
    },
  );

  test('payment read keeps date order, IDs and historical defaults', () async {
    final payments = db
        .collection('users')
        .doc('alice')
        .collection('loans')
        .doc('loan')
        .collection('payments');
    await payments.doc('emi_2026-01-05').set({
      'amount': 1000,
      'remainingPrincipalAfter': 9000,
      'date': Timestamp.fromDate(DateTime(2026, 1, 5)),
      'type': 'emi',
    });
    await payments.doc('partial').set({
      'amount': 500,
      'date': Timestamp.fromDate(DateTime(2026, 2, 5)),
      'type': 'partial',
    });

    final results = await repository.payments('alice', 'loan').first;
    expect(results.map((payment) => payment.id), ['partial', 'emi_2026-01-05']);
    expect(results.first.type, PersonalLoanPaymentType.partial);
    expect(results.last.remainingPrincipalAfter, 9000);
    expect(results.last.principalComponent, 0);
    expect(await repository.payments('bob', 'loan').first, isEmpty);
  });

  test(
    'regular EMI writes paired stable IDs and a retry does not duplicate',
    () async {
      final loan = db.doc('users/alice/loans/home');
      await loan.set({
        'userId': 'alice',
        'title': 'Home loan',
        'loanType': 'borrowed',
        'principal': 12000,
        'annualInterestRate': 12,
        'tenureMonths': 12,
        'startDate': Timestamp.fromDate(DateTime(2026, 1)),
        'emiDueDay': 5,
        'status': 'active',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1)),
      });
      final record = RecordPersonalEmiPayment(repository);
      final date = DateTime(2026, 2, 5);
      await record('alice', 'home', 12000, date);
      await record('alice', 'home', 12000, date);

      final payments = await loan.collection('payments').get();
      final expenses = await db
          .collection('users')
          .doc('alice')
          .collection('personal_transactions')
          .get();
      expect(payments.docs, hasLength(1));
      expect(expenses.docs, hasLength(1));
      expect(payments.docs.single.id, 'emi_2026-02-05');
      expect(expenses.docs.single.id, 'loan_home_emi_2026-02-05');
      expect(expenses.docs.single.data()['loanSourceId'], 'home');
      expect(expenses.docs.single.data()['category'], 'Loan EMI');
      expect(expenses.docs.single.data()['month'], '2026-02');
      expect(expenses.docs.single.data()['partialSettlements'], isEmpty);
      expect(payments.docs.single.data()['interestComponent'], 120);
      expect(
        payments.docs.single.data()['amount'],
        closeTo((await repository.get('alice', 'home')).baseEmi, 0.000001),
      );
      expect((await loan.get()).data()!['status'], 'active');
    },
  );

  test(
    'final regular EMI settles loan and deactivates linked recurring',
    () async {
      final loan = db.doc('users/alice/loans/home');
      final recurring = db.doc('users/alice/personal_recurring/linked');
      await loan.set({
        'userId': 'alice',
        'title': 'Home loan',
        'principal': 1000,
        'annualInterestRate': 0,
        'tenureMonths': 1,
        'recurringId': 'linked',
      });
      await recurring.set({'active': true});

      await RecordPersonalEmiPayment(repository)(
        'alice',
        'home',
        1000,
        DateTime(2026, 2, 5),
      );

      expect((await loan.get()).data()!['status'], 'settled');
      final recurringData = (await recurring.get()).data()!;
      expect(recurringData['active'], false);
      expect(recurringData['endDate'], isA<Timestamp>());
      expect(
        (await loan.collection('payments').get()).docs.single
            .data()['remainingPrincipalAfter'],
        0,
      );
    },
  );
  test(
    'missed EMI command rechecks dates and uses paired stable writes',
    () async {
      final loan = db.doc('users/alice/loans/backdated');
      await loan.set({
        'userId': 'alice',
        'title': 'Backdated loan',
        'principal': 12000,
        'annualInterestRate': 0,
        'tenureMonths': 3,
        'startDate': Timestamp.fromDate(DateTime(2025, 12, 1)),
        'emiStartDate': Timestamp.fromDate(DateTime(2026, 1, 5)),
        'emiDueDay': 5,
        'status': 'active',
      });
      await loan.collection('payments').doc('emi_2026-01-05').set({
        'amount': 4000,
        'principalComponent': 4000,
        'interestComponent': 0,
        'remainingPrincipalAfter': 8000,
        'date': Timestamp.fromDate(DateTime(2026, 1, 5)),
        'type': 'emi',
      });
      final record = RecordMissedPersonalEmis(
        repository,
        clock: () => DateTime(2026, 3, 1),
      );
      await record('alice', 'backdated', [
        DateTime(2026, 2, 5),
        DateTime(2026, 1, 5),
        DateTime(2026, 2, 5),
      ]);

      final payments = await loan.collection('payments').get();
      final expenses = await db
          .collection('users')
          .doc('alice')
          .collection('personal_transactions')
          .get();
      expect(payments.docs, hasLength(2));
      expect(expenses.docs, hasLength(1));
      expect(expenses.docs.single.id, 'loan_backdated_emi_2026-02-05');
      final backdated = payments.docs.singleWhere(
        (doc) => doc.id == 'emi_2026-02-05',
      );
      expect(backdated.data()['note'], 'Backdated EMI');
      expect(backdated.data()['remainingPrincipalAfter'], 4000);
      expect((await loan.get()).data()!['status'], 'active');
    },
  );

  test(
    'multiple missed EMIs reduce principal in date order and settle',
    () async {
      final loan = db.doc('users/alice/loans/two');
      await loan.set({
        'userId': 'alice',
        'title': 'Two installments',
        'principal': 2000,
        'annualInterestRate': 0,
        'tenureMonths': 2,
        'startDate': Timestamp.fromDate(DateTime(2025, 12, 1)),
        'emiStartDate': Timestamp.fromDate(DateTime(2026, 1, 5)),
        'emiDueDay': 5,
        'status': 'active',
      });
      await RecordMissedPersonalEmis(
        repository,
        clock: () => DateTime(2026, 3, 1),
      )('alice', 'two', [DateTime(2026, 2, 5), DateTime(2026, 1, 5)]);

      final payments = await loan.collection('payments').get();
      expect(payments.docs, hasLength(2));
      expect(
        payments.docs
            .singleWhere((doc) => doc.id == 'emi_2026-01-05')
            .data()['remainingPrincipalAfter'],
        1000,
      );
      expect(
        payments.docs
            .singleWhere((doc) => doc.id == 'emi_2026-02-05')
            .data()['remainingPrincipalAfter'],
        0,
      );
      expect((await loan.get()).data()!['status'], 'settled');
      expect(
        (await db
                .collection('users')
                .doc('alice')
                .collection('personal_transactions')
                .get())
            .docs,
        hasLength(2),
      );
    },
  );
  test(
    'partial payment splits interest, updates recurring and links one expense per day',
    () async {
      final loan = db.doc('users/alice/loans/partial');
      final recurring = db.doc('users/alice/personal_recurring/linked');
      await loan.set({
        'userId': 'alice',
        'title': 'Partial loan',
        'principal': 12000,
        'annualInterestRate': 12,
        'tenureMonths': 12,
        'startDate': Timestamp.fromDate(DateTime(2026, 1)),
        'emiDueDay': 5,
        'status': 'active',
        'recurringId': 'linked',
      });
      await recurring.set({'active': true, 'amount': 1100});
      await loan.collection('payments').doc('emi_2026-02-05').set({
        'amount': 1100,
        'date': Timestamp.fromDate(DateTime(2026, 2, 5)),
        'type': 'emi',
        'remainingPrincipalAfter': 12000,
      });
      final record = RecordPersonalPartialPayment(repository);
      final date = DateTime(2026, 3, 10);
      await record('alice', 'partial', 12000, 2000, date, note: 'Extra');
      await record('alice', 'partial', 12000, 2000, date, note: 'Extra');

      final payments = await loan.collection('payments').get();
      final partials = payments.docs
          .where((doc) => doc.data()['type'] == 'partial')
          .toList();
      final expenses = await db
          .collection('users')
          .doc('alice')
          .collection('personal_transactions')
          .get();
      expect(partials, hasLength(2));
      expect(partials.first.data()['interestComponent'], 120);
      expect(partials.first.data()['principalComponent'], 1880);
      expect(partials.first.data()['remainingPrincipalAfter'], 10120);
      expect(partials.first.data()['note'], 'Extra');
      expect(expenses.docs, hasLength(1));
      expect(expenses.docs.single.data()['loanSourceId'], 'partial');
      expect(
        expenses.docs.single.data()['title'],
        'Partial loan – Partial Payment',
      );
      expect(
        (await recurring.get()).data()!['amount'],
        closeTo(976.115246197991, 0.000001),
      );
      expect((await loan.get()).data()!['status'], 'active');
    },
  );

  test(
    'final partial payment settles and deactivates linked recurring',
    () async {
      final loan = db.doc('users/alice/loans/partial');
      final recurring = db.doc('users/alice/personal_recurring/linked');
      await loan.set({
        'userId': 'alice',
        'title': 'Final partial',
        'principal': 1000,
        'annualInterestRate': 0,
        'tenureMonths': 2,
        'recurringId': 'linked',
      });
      await recurring.set({'active': true, 'amount': 500});
      await RecordPersonalPartialPayment(repository)(
        'alice',
        'partial',
        1000,
        1000,
        DateTime(2026, 3, 10),
      );

      expect((await loan.get()).data()!['status'], 'settled');
      final recurringData = (await recurring.get()).data()!;
      expect(recurringData['active'], false);
      expect(recurringData['endDate'], isA<Timestamp>());
      expect(recurringData['amount'], 500);
    },
  );
  test(
    'foreclosure records payoff, linked expense and closes recurring',
    () async {
      final loan = db.doc('users/alice/loans/foreclosure');
      final recurring = db.doc('users/alice/personal_recurring/linked');
      await loan.set({
        'userId': 'alice',
        'title': 'Borrowed loan',
        'loanType': 'borrowed',
        'principal': 12000,
        'annualInterestRate': 12,
        'tenureMonths': 12,
        'recurringId': 'linked',
        'status': 'active',
      });
      await recurring.set({'active': true});
      final date = DateTime(2026, 3, 10);
      await ForeclosePersonalLoan(repository, clock: () => date)(
        'alice',
        'foreclosure',
        5000,
      );

      final payments = await loan.collection('payments').get();
      expect(payments.docs, hasLength(1));
      final payment = payments.docs.single.data();
      expect(payment['type'], 'foreclosure');
      expect(payment['amount'], 5050);
      expect(payment['principalComponent'], 5000);
      expect(payment['interestComponent'], 50);
      expect(payment['remainingPrincipalAfter'], 0);
      expect(payment['note'], 'Foreclosure / Force Close');
      final expenses = await db
          .collection('users')
          .doc('alice')
          .collection('personal_transactions')
          .get();
      expect(expenses.docs, hasLength(1));
      final expense = expenses.docs.single.data();
      expect(expense['title'], 'Borrowed loan – Foreclosure');
      expect(expense['amount'], 5050);
      expect(expense['type'], 'expense');
      expect(expense['loanSourceId'], 'foreclosure');
      expect(expense['month'], '2026-03');
      expect((await loan.get()).data()!['status'], 'foreclosed');
      final recurringData = (await recurring.get()).data()!;
      expect(recurringData['active'], false);
      expect(recurringData['endDate'], isA<Timestamp>());
    },
  );

  test(
    'same-day foreclosure retries append payment but share expense',
    () async {
      final loan = db.doc('users/alice/loans/foreclosure');
      await loan.set({
        'userId': 'alice',
        'title': 'Loan',
        'principal': 1000,
        'annualInterestRate': 0,
        'tenureMonths': 1,
        'status': 'active',
      });
      final command = ForeclosePersonalLoan(
        repository,
        clock: () => DateTime(2026, 3, 10),
      );
      await command('alice', 'foreclosure', 1000);
      await command('alice', 'foreclosure', 1000);

      expect((await loan.collection('payments').get()).docs, hasLength(2));
      expect(
        (await db
                .collection('users')
                .doc('alice')
                .collection('personal_transactions')
                .get())
            .docs,
        hasLength(1),
      );
      expect((await loan.get()).data()!['status'], 'foreclosed');
    },
  );
  test(
    'create preserves the legacy loan schema and server timestamp',
    () async {
      final loan = PersonalLoan(
        id: '',
        userId: 'alice',
        title: 'New loan',
        loanType: PersonalLoanType.lent,
        principal: 5000,
        annualInterestRate: 10,
        tenureMonths: 10,
        startDate: DateTime(2026, 1, 5),
        emiDueDay: 6,
        status: PersonalLoanStatus.active,
        createdAt: DateTime(2020),
        lenderBorrowerName: 'Alex',
        notes: 'Agreement',
        customEmi: 700,
        processingFee: 50,
        insuranceFee: 20,
        otherCharges: 10,
        gstOnFees: 9,
        emiStartDate: DateTime(2026, 2, 6),
      );
      final id = await SavePersonalLoan(repository).create('alice', loan);
      final data = (await db.doc('users/alice/loans/$id').get()).data()!;
      expect(data['userId'], 'alice');
      expect(data['loanType'], 'lent');
      expect(data['status'], 'active');
      expect(data['customEmi'], 700);
      expect(data['processingFee'], 50);
      expect(data['emiStartDate'], isA<Timestamp>());
      expect(data['createdAt'], isA<Timestamp>());
      expect(await repository.get('alice', id), isA<PersonalLoan>());
      expect(await repository.loans('bob').first, isEmpty);
    },
  );

  test(
    'edit preserves linked recurring update and custom EMI clearing behavior',
    () async {
      final loan = db.doc('users/alice/loans/edit');
      final recurring = db.doc('users/alice/personal_recurring/linked');
      await loan.set({
        'userId': 'alice',
        'title': 'Edit loan',
        'loanType': 'borrowed',
        'principal': 12000,
        'annualInterestRate': 12,
        'tenureMonths': 12,
        'startDate': Timestamp.fromDate(DateTime(2026, 1)),
        'emiDueDay': 5,
        'status': 'active',
        'customEmi': 1800,
        'recurringId': 'linked',
      });
      await recurring.set({'amount': 1800, 'dayOfMonth': 5});
      await SavePersonalLoan(repository).update(
        'alice',
        'edit',
        const PersonalLoanChanges(
          principal: 10000,
          annualInterestRate: 10,
          tenureMonths: 10,
          emiDueDay: 7,
          customEmi: 0,
          processingFee: 25,
        ),
      );
      final loanData = (await loan.get()).data()!;
      expect(loanData['principal'], 10000);
      expect(loanData['customEmi'], isNull);
      expect(loanData['processingFee'], 25);
      final recurringData = (await recurring.get()).data()!;
      expect(recurringData['amount'], 1800);
      expect(recurringData['dayOfMonth'], 7);
    },
  );

  test(
    'delete removes loan payments but leaves linked recurring and expense',
    () async {
      final loan = db.doc('users/alice/loans/remove');
      final recurring = db.doc('users/alice/personal_recurring/linked');
      final expense = db.doc('users/alice/personal_transactions/old');
      await loan.set({'title': 'Remove', 'recurringId': 'linked'});
      await loan.collection('payments').doc('first').set({'amount': 1});
      await loan.collection('payments').doc('second').set({'amount': 2});
      await recurring.set({'active': true});
      await expense.set({'loanSourceId': 'remove'});

      await DeletePersonalLoan(repository)('alice', 'remove');

      expect((await loan.get()).exists, false);
      expect((await loan.collection('payments').get()).docs, isEmpty);
      expect((await recurring.get()).exists, true);
      expect((await expense.get()).exists, true);
    },
  );
}
