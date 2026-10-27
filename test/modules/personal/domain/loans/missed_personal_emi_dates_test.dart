import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_payment.dart';
import 'package:split_ex/modules/personal/domain/policies/loans/missed_personal_emi_dates.dart';

void main() {
  final loan = PersonalLoan(
    id: 'loan',
    userId: 'alice',
    title: 'Loan',
    loanType: PersonalLoanType.borrowed,
    principal: 12000,
    annualInterestRate: 0,
    tenureMonths: 3,
    startDate: DateTime(2025, 11, 30),
    emiDueDay: 31,
    status: PersonalLoanStatus.active,
    createdAt: DateTime(2025, 11, 30),
    emiStartDate: DateTime(2026, 1, 31),
  );

  test('clamps month end and consumes one payment per due date', () {
    final payments = [
      PersonalLoanPayment(
        id: 'paid',
        amount: 4000,
        principalComponent: 4000,
        interestComponent: 0,
        remainingPrincipalAfter: 8000,
        date: DateTime(2026, 2, 3),
        type: PersonalLoanPaymentType.emi,
      ),
      PersonalLoanPayment(
        id: 'partial',
        amount: 500,
        principalComponent: 500,
        interestComponent: 0,
        remainingPrincipalAfter: 7500,
        date: DateTime(2026, 2, 28),
        type: PersonalLoanPaymentType.partial,
      ),
    ];
    expect(missedPersonalEmiDates(loan, payments, DateTime(2026, 3, 31)), [
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
    ]);
    expect(
      missedPersonalEmiDates(loan, payments, DateTime(2026, 2, 20)),
      isEmpty,
    );
  });
}
