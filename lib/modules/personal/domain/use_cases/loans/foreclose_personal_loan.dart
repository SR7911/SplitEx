import '../../entities/loans/personal_loan_payment.dart';
import '../../repositories/personal_loan_repository.dart';

class ForeclosePersonalLoan {
  final PersonalLoanRepository _repository;
  final DateTime Function() _clock;

  ForeclosePersonalLoan(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  Future<void> call(
    String userId,
    String loanId,
    double remainingPrincipal,
  ) async {
    final loan = await _repository.get(userId, loanId);
    final date = _clock();
    final accruedInterest =
        remainingPrincipal * loan.annualInterestRate / (12 * 100);
    final payment = PersonalLoanPayment(
      id: '',
      amount: remainingPrincipal + accruedInterest,
      principalComponent: remainingPrincipal,
      interestComponent: accruedInterest,
      remainingPrincipalAfter: 0,
      date: date,
      type: PersonalLoanPaymentType.foreclosure,
      note: 'Foreclosure / Force Close',
    );
    await _repository.recordForeclosure(userId, loan, payment);
    await _repository.foreclose(userId, loan);
  }
}
