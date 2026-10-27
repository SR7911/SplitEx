import '../../entities/loans/personal_loan_payment.dart';
import '../../repositories/personal_loan_repository.dart';

/// Records one regular EMI and its paired Personal expense.
class RecordPersonalEmiPayment {
  final PersonalLoanRepository _repository;

  const RecordPersonalEmiPayment(this._repository);

  Future<void> call(
    String userId,
    String loanId,
    double remainingPrincipal,
    DateTime paymentDate,
  ) async {
    final loan = await _repository.get(userId, loanId);
    final interest = remainingPrincipal * loan.annualInterestRate / (12 * 100);
    final emi = loan.baseEmi;
    final principalPaid = emi - interest;
    final remaining = (remainingPrincipal - principalPaid).clamp(
      0.0,
      double.infinity,
    );
    final payment = PersonalLoanPayment(
      id: '',
      amount: emi,
      principalComponent: principalPaid,
      interestComponent: interest,
      remainingPrincipalAfter: remaining,
      date: paymentDate,
      type: PersonalLoanPaymentType.emi,
    );
    await _repository.recordEmi(userId, loan, payment);
    if (remaining < 1.0) {
      await _repository.settle(userId, loan);
    }
  }
}
