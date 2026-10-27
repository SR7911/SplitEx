import '../../entities/loans/personal_loan_payment.dart';
import '../../repositories/personal_loan_repository.dart';

class RecordPersonalPartialPayment {
  final PersonalLoanRepository _repository;

  const RecordPersonalPartialPayment(this._repository);

  Future<void> call(
    String userId,
    String loanId,
    double remainingPrincipal,
    double amount,
    DateTime paymentDate, {
    String? note,
  }) async {
    final loan = await _repository.get(userId, loanId);
    final monthlyRate = loan.annualInterestRate / (12 * 100);
    final interest = (remainingPrincipal * monthlyRate).clamp(0.0, amount);
    final principalPaid = (amount - interest).clamp(0.0, remainingPrincipal);
    final remaining = (remainingPrincipal - principalPaid).clamp(
      0.0,
      double.infinity,
    );
    await _repository.recordPartialPayment(
      userId,
      loan,
      PersonalLoanPayment(
        id: '',
        amount: amount,
        principalComponent: principalPaid,
        interestComponent: interest,
        remainingPrincipalAfter: remaining,
        date: paymentDate,
        type: PersonalLoanPaymentType.partial,
        note: note,
      ),
    );
    if (loan.recurringId != null && remaining > 1.0) {
      final monthsPaid = await _repository.countEmiPayments(userId, loanId);
      final remainingMonths = (loan.tenureMonths - monthsPaid).clamp(
        1,
        loan.tenureMonths,
      );
      final newEmi = _calculateEmi(
        remaining,
        loan.annualInterestRate,
        remainingMonths,
      );
      await _repository.updateRecurringAmount(
        userId,
        loan.recurringId!,
        newEmi,
      );
    }
    if (remaining < 1.0) {
      await _repository.settle(userId, loan);
    }
  }

  double _calculateEmi(double principal, double annualRate, int months) {
    if (annualRate == 0) return principal / months;
    final rate = annualRate / (12 * 100);
    var factor = 1.0;
    for (var month = 0; month < months; month++) {
      factor *= 1 + rate;
    }
    return principal * rate * factor / (factor - 1);
  }
}
