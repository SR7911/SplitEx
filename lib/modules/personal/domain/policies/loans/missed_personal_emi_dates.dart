import '../../entities/loans/personal_loan.dart';
import '../../entities/loans/personal_loan_payment.dart';

/// Due dates without a matching EMI payment within the existing 15-day window.
List<DateTime> missedPersonalEmiDates(
  PersonalLoan loan,
  List<PersonalLoanPayment> payments,
  DateTime now,
) {
  if (loan.status != PersonalLoanStatus.active) return [];
  final emiPayments =
      payments
          .where((payment) => payment.type == PersonalLoanPaymentType.emi)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  final missed = <DateTime>[];
  for (var index = 1; index <= loan.tenureMonths; index++) {
    final reference = loan.effectiveEmiStart;
    final rawMonth = reference.month + index - 1;
    final year = reference.year + (rawMonth - 1) ~/ 12;
    final month = ((rawMonth - 1) % 12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final due = DateTime(year, month, loan.emiDueDay.clamp(1, maxDay));
    if (due.isAfter(now)) break;
    final match = emiPayments.indexWhere(
      (payment) => payment.date.difference(due).inDays.abs() <= 15,
    );
    if (match >= 0) {
      emiPayments.removeAt(match);
    } else {
      missed.add(due);
    }
  }
  return missed;
}
