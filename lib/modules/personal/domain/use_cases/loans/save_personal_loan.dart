import '../../entities/loans/personal_loan.dart';
import '../../entities/loans/personal_loan_changes.dart';
import '../../repositories/personal_loan_repository.dart';

class SavePersonalLoan {
  final PersonalLoanRepository _repository;

  const SavePersonalLoan(this._repository);

  Future<String> create(String userId, PersonalLoan loan) =>
      _repository.add(userId, loan);

  Future<void> update(
    String userId,
    String loanId,
    PersonalLoanChanges changes,
  ) async {
    final loan = await _repository.get(userId, loanId);
    // Preserve the existing edit behavior: the linked recurring amount is
    // calculated using the currently stored custom EMI, if any.
    final recurringAmount = calculatePersonalLoanEmi(
      changes.principal ?? loan.principal,
      changes.annualInterestRate ?? loan.annualInterestRate,
      changes.tenureMonths ?? loan.tenureMonths,
      customEmi: loan.customEmi,
    );
    await _repository.update(userId, loan, changes, recurringAmount);
  }
}

class DeletePersonalLoan {
  final PersonalLoanRepository _repository;

  const DeletePersonalLoan(this._repository);

  Future<void> call(String userId, String loanId) =>
      _repository.delete(userId, loanId);
}
