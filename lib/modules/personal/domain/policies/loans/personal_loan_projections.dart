import '../../entities/loans/personal_amortization_entry.dart';
import '../../entities/loans/personal_loan.dart';
import '../../entities/loans/personal_loan_payment.dart';
import '../../entities/loans/personal_loan_overview.dart';

double personalLoanRemainingPrincipal(
  PersonalLoan loan,
  List<PersonalLoanPayment> payments,
) {
  if (payments.isEmpty) return loan.principal;
  final sorted = [...payments]..sort((a, b) => b.date.compareTo(a.date));
  return sorted.first.remainingPrincipalAfter;
}

PersonalLoanEmiProgress personalLoanEmiProgress(
  PersonalLoan loan,
  List<PersonalLoanPayment> payments,
  DateTime now,
) {
  final paidCount = payments
      .where((payment) => payment.type == PersonalLoanPaymentType.emi)
      .length;
  DateTime? nextDueDate;
  for (var index = paidCount + 1; index <= loan.tenureMonths; index++) {
    final due = _nthEmiDate(loan, index);
    if (!due.isBefore(now)) {
      nextDueDate = due;
      break;
    }
  }
  return PersonalLoanEmiProgress(
    paidCount: paidCount,
    totalCount: loan.tenureMonths,
    nextDueDate: nextDueDate,
  );
}

PersonalLoanSummary personalLoanSummary(
  List<PersonalLoan> loans,
  Map<String, List<PersonalLoanPayment>> paymentsByLoan,
) {
  var outstanding = 0.0;
  var monthlyEmi = 0.0;
  var activeCount = 0;
  for (final loan in loans) {
    if (loan.status != PersonalLoanStatus.active) continue;
    activeCount++;
    outstanding += personalLoanRemainingPrincipal(
      loan,
      paymentsByLoan[loan.id] ?? const [],
    );
    monthlyEmi += loan.baseEmi;
  }
  return PersonalLoanSummary(
    totalOutstanding: outstanding,
    totalMonthlyEmi: monthlyEmi,
    activeCount: activeCount,
  );
}

/// The existing local amortization projection, including its payment ordering.
List<PersonalAmortizationEntry> buildPersonalLoanSchedule(
  PersonalLoan loan,
  List<PersonalLoanPayment> payments,
) {
  final entries = <PersonalAmortizationEntry>[];
  var remaining = loan.principal;
  final monthlyRate = loan.annualInterestRate / (12 * 100);
  final sortedPayments = [...payments]
    ..sort((a, b) => a.date.compareTo(b.date));
  var emiPaymentIndex = 0;
  var partialAppliedUpTo = -1;

  for (var index = 1; index <= loan.tenureMonths; index++) {
    final dueDate = _nthEmiDate(loan, index);
    for (
      var paymentIndex = partialAppliedUpTo + 1;
      paymentIndex < sortedPayments.length;
      paymentIndex++
    ) {
      final payment = sortedPayments[paymentIndex];
      if (payment.type == PersonalLoanPaymentType.partial &&
          payment.date.isBefore(dueDate)) {
        remaining = payment.remainingPrincipalAfter;
        partialAppliedUpTo = paymentIndex;
      }
    }

    final interest = remaining * monthlyRate;
    final emi = loan.baseEmi;
    final principalPaid = (emi - interest).clamp(0.0, remaining);
    final newRemaining = (remaining - principalPaid).clamp(
      0.0,
      double.infinity,
    );

    var isPaid = false;
    if (emiPaymentIndex < sortedPayments.length) {
      final payment = sortedPayments[emiPaymentIndex];
      if (!payment.date.isAfter(dueDate) &&
          payment.type == PersonalLoanPaymentType.emi) {
        isPaid = true;
        emiPaymentIndex++;
        remaining = payment.remainingPrincipalAfter;
      }
    }

    entries.add(
      PersonalAmortizationEntry(
        month: index,
        dueDate: dueDate,
        emi: emi,
        principal: principalPaid,
        interest: interest,
        remainingPrincipal: newRemaining,
        isPaid: isPaid,
      ),
    );
    if (!isPaid) remaining = newRemaining;
  }
  return entries;
}

DateTime _nthEmiDate(PersonalLoan loan, int index) {
  final reference = loan.effectiveEmiStart;
  final rawMonth = reference.month + index - 1;
  final year = reference.year + (rawMonth - 1) ~/ 12;
  final month = ((rawMonth - 1) % 12) + 1;
  final maxDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, loan.emiDueDay.clamp(1, maxDay));
}
