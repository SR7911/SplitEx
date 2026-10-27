import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dependencies.dart';
import '../../../domain/entities/loans/personal_loan.dart';
import '../../../domain/entities/loans/personal_loan_payment.dart';
import '../../../domain/entities/loans/personal_amortization_entry.dart';
import '../../../domain/entities/loans/personal_loan_overview.dart';
import '../../../domain/policies/loans/personal_loan_projections.dart';

final personalLoansProvider = StreamProvider<List<PersonalLoan>>((ref) {
  final userId = ref.watch(personalUserIdProvider).valueOrNull;
  if (userId == null) return Stream.value([]);
  return ref.watch(personalLoanRepositoryProvider).loans(userId);
});

final personalLoanPaymentsProvider =
    StreamProvider.family<List<PersonalLoanPayment>, String>((ref, loanId) {
      final userId = ref.watch(personalUserIdProvider).valueOrNull;
      if (userId == null) return Stream.value([]);
      return ref.watch(personalLoanRepositoryProvider).payments(userId, loanId);
    });

final personalLoanRemainingPrincipalProvider = Provider.family<double, String>((
  ref,
  loanId,
) {
  final loans = ref.watch(personalLoansProvider).valueOrNull ?? [];
  final matches = loans.where((loan) => loan.id == loanId);
  if (matches.isEmpty) return 0;
  final payments =
      ref.watch(personalLoanPaymentsProvider(loanId)).valueOrNull ?? [];
  return personalLoanRemainingPrincipal(matches.first, payments);
});

final personalLoanScheduleProvider =
    Provider.family<List<PersonalAmortizationEntry>, String>((ref, loanId) {
      final loans = ref.watch(personalLoansProvider).valueOrNull ?? [];
      final matches = loans.where((loan) => loan.id == loanId);
      if (matches.isEmpty) return [];
      final payments =
          ref.watch(personalLoanPaymentsProvider(loanId)).valueOrNull ?? [];
      return buildPersonalLoanSchedule(matches.first, payments);
    });

final personalLoanEmiProgressProvider =
    Provider.family<PersonalLoanEmiProgress, String>((ref, loanId) {
      final loans = ref.watch(personalLoansProvider).valueOrNull ?? [];
      final matches = loans.where((loan) => loan.id == loanId);
      if (matches.isEmpty) {
        return const PersonalLoanEmiProgress(paidCount: 0, totalCount: 0);
      }
      final payments =
          ref.watch(personalLoanPaymentsProvider(loanId)).valueOrNull ?? [];
      return personalLoanEmiProgress(matches.first, payments, DateTime.now());
    });

final personalLoanSummaryProvider = Provider<PersonalLoanSummary>((ref) {
  final loans = ref.watch(personalLoansProvider).valueOrNull ?? [];
  final paymentsByLoan = <String, List<PersonalLoanPayment>>{};
  for (final loan in loans.where(
    (loan) => loan.status == PersonalLoanStatus.active,
  )) {
    paymentsByLoan[loan.id] =
        ref.watch(personalLoanPaymentsProvider(loan.id)).valueOrNull ?? [];
  }
  return personalLoanSummary(loans, paymentsByLoan);
});
