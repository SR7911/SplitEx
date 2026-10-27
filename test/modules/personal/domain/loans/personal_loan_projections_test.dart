import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_payment.dart';
import 'package:split_ex/modules/personal/domain/policies/loans/personal_loan_projections.dart';

void main() {
  final loan = PersonalLoan(
    id: 'loan',
    userId: 'alice',
    title: 'Loan',
    loanType: PersonalLoanType.borrowed,
    principal: 1200,
    annualInterestRate: 0,
    tenureMonths: 2,
    startDate: DateTime(2026, 1, 5),
    emiDueDay: 5,
    status: PersonalLoanStatus.active,
    createdAt: DateTime(2026, 1, 5),
  );

  PersonalLoanPayment payment(
    String id,
    DateTime date,
    double balance,
    PersonalLoanPaymentType type,
  ) => PersonalLoanPayment(
    id: id,
    amount: 600,
    principalComponent: 600,
    interestComponent: 0,
    remainingPrincipalAfter: balance,
    date: date,
    type: type,
  );

  test('latest payment determines balance regardless of input order', () {
    final payments = [
      payment('new', DateTime(2026, 3, 5), 100, PersonalLoanPaymentType.emi),
      payment('old', DateTime(2026, 2, 5), 600, PersonalLoanPaymentType.emi),
    ];
    expect(personalLoanRemainingPrincipal(loan, []), 1200);
    expect(
      personalLoanRemainingPrincipal(loan, payments.reversed.toList()),
      100,
    );
  });

  test('schedule clamps due dates and marks the first recorded EMI paid', () {
    final entries = buildPersonalLoanSchedule(loan, [
      payment('emi', DateTime(2026, 2, 5), 600, PersonalLoanPaymentType.emi),
    ]);
    expect(entries.map((entry) => entry.dueDate), [
      DateTime(2026, 2, 5),
      DateTime(2026, 3, 5),
    ]);
    expect(entries.map((entry) => entry.isPaid), [true, false]);
    expect(entries.map((entry) => entry.remainingPrincipal), [600, 0]);
  });

  test('schedule applies earlier partial balance using existing ordering', () {
    final entries = buildPersonalLoanSchedule(loan, [
      payment(
        'partial',
        DateTime(2026, 2, 20),
        500,
        PersonalLoanPaymentType.partial,
      ),
      payment('emi', DateTime(2026, 2, 5), 600, PersonalLoanPaymentType.emi),
    ]);
    expect(entries.first.isPaid, true);
    expect(entries.last.isPaid, false);
    expect(entries.last.principal, 500);
    expect(entries.last.remainingPrincipal, 0);
  });

  test('EMI progress counts EMI logs and skips dates before now', () {
    final payments = [
      payment('emi', DateTime(2026, 2, 5), 600, PersonalLoanPaymentType.emi),
      payment(
        'partial',
        DateTime(2026, 2, 20),
        500,
        PersonalLoanPaymentType.partial,
      ),
    ];
    final progress = personalLoanEmiProgress(
      loan,
      payments,
      DateTime(2026, 2, 28),
    );
    expect(progress.paidCount, 1);
    expect(progress.totalCount, 2);
    expect(progress.nextDueDate, DateTime(2026, 3, 5));
    expect(
      personalLoanEmiProgress(loan, payments, DateTime(2026, 3, 6)).nextDueDate,
      isNull,
    );
  });

  test('summary includes active loans only and uses latest balances', () {
    final settled = PersonalLoan(
      id: 'settled',
      userId: 'alice',
      title: 'Closed',
      loanType: PersonalLoanType.borrowed,
      principal: 500,
      annualInterestRate: 0,
      tenureMonths: 1,
      startDate: DateTime(2026, 1),
      emiDueDay: 5,
      status: PersonalLoanStatus.settled,
      createdAt: DateTime(2026, 1),
    );
    final summary = personalLoanSummary(
      [loan, settled],
      {
        loan.id: [
          payment(
            'latest',
            DateTime(2026, 3, 5),
            300,
            PersonalLoanPaymentType.emi,
          ),
        ],
      },
    );
    expect(summary.activeCount, 1);
    expect(summary.totalOutstanding, 300);
    expect(summary.totalMonthlyEmi, 600);
  });
}
