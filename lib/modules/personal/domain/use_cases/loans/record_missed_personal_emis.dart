import '../../entities/loans/personal_loan_payment.dart';
import '../../policies/loans/missed_personal_emi_dates.dart';
import '../../repositories/personal_loan_repository.dart';

/// Rechecks requested dates before recording backdated EMIs in due-date order.
class RecordMissedPersonalEmis {
  final PersonalLoanRepository _repository;
  final DateTime Function() _clock;

  RecordMissedPersonalEmis(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  Future<void> call(
    String userId,
    String loanId,
    List<DateTime> requestedDates,
  ) async {
    final loan = await _repository.get(userId, loanId);
    final payments = await _repository.payments(userId, loanId).first;
    var remaining = payments.isEmpty
        ? loan.principal
        : payments.first.remainingPrincipalAfter;
    final stillMissed = missedPersonalEmiDates(
      loan,
      payments,
      _clock(),
    ).toSet();
    final dates = requestedDates.toSet().where(stillMissed.contains).toList()
      ..sort();
    final monthlyRate = loan.annualInterestRate / (12 * 100);
    for (final dueDate in dates) {
      if (remaining < 1.0) break;
      final interest = remaining * monthlyRate;
      final emi = loan.baseEmi;
      final principalPaid = (emi - interest).clamp(0.0, remaining);
      remaining = (remaining - principalPaid).clamp(0.0, double.infinity);
      await _repository.recordEmi(
        userId,
        loan,
        PersonalLoanPayment(
          id: '',
          amount: emi,
          principalComponent: principalPaid,
          interestComponent: interest,
          remainingPrincipalAfter: remaining,
          date: dueDate,
          type: PersonalLoanPaymentType.emi,
          note: 'Backdated EMI',
        ),
      );
    }
    if (remaining < 1.0) {
      await _repository.settle(userId, loan);
    }
  }
}
