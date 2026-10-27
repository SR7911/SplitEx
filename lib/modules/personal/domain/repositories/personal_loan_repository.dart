import '../entities/loans/personal_loan.dart';
import '../entities/loans/personal_loan_payment.dart';
import '../entities/loans/personal_loan_changes.dart';

abstract class PersonalLoanRepository {
  Stream<List<PersonalLoan>> loans(String userId);
  Stream<List<PersonalLoanPayment>> payments(String userId, String loanId);
  Future<PersonalLoan> get(String userId, String loanId);
  Future<String> add(String userId, PersonalLoan loan);
  Future<void> update(
    String userId,
    PersonalLoan loan,
    PersonalLoanChanges changes,
    double recurringAmount,
  );
  Future<void> delete(String userId, String loanId);
  Future<void> recordEmi(
    String userId,
    PersonalLoan loan,
    PersonalLoanPayment payment,
  );
  Future<void> settle(String userId, PersonalLoan loan);
  Future<void> recordPartialPayment(
    String userId,
    PersonalLoan loan,
    PersonalLoanPayment payment,
  );
  Future<int> countEmiPayments(String userId, String loanId);
  Future<void> updateRecurringAmount(
    String userId,
    String recurringId,
    double amount,
  );
  Future<void> recordForeclosure(
    String userId,
    PersonalLoan loan,
    PersonalLoanPayment payment,
  );
  Future<void> foreclose(String userId, PersonalLoan loan);
}
