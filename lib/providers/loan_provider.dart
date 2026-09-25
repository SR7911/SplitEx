import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/services/loan_service.dart';

final loanServiceProvider = Provider<LoanService>((ref) => LoanService());

// ── All loans for current user ────────────────────────────────────────────

final loansProvider = StreamProvider<List<LoanModel>>((ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(loanServiceProvider).getLoansStream(userId);
});

// ── Payments for a specific loan ──────────────────────────────────────────

final loanPaymentsProvider =
    StreamProvider.family<List<LoanPaymentModel>, String>((ref, loanId) {
  final userId = ref.watch(authStateProvider).valueOrNull?.uid;
  if (userId == null) return Stream.value([]);
  return ref.watch(loanServiceProvider).getPaymentsStream(userId, loanId);
});

// ── Computed: remaining principal for a loan ──────────────────────────────
// Derived from the last payment's remainingPrincipalAfter, or full principal if no payments.

final loanRemainingPrincipalProvider =
    Provider.family<double, String>((ref, loanId) {
  final loans = ref.watch(loansProvider).valueOrNull ?? [];
  final loanList = loans.where((l) => l.id == loanId).toList();
  if (loanList.isEmpty) return 0;
  final loan = loanList.first;
  final payments = ref.watch(loanPaymentsProvider(loanId)).valueOrNull ?? [];
  if (payments.isEmpty) return loan.principal;
  final sorted = [...payments]..sort((a, b) => b.date.compareTo(a.date));
  return sorted.first.remainingPrincipalAfter;
});

// ── Computed: amortization schedule ──────────────────────────────────────

final loanScheduleProvider =
    Provider.family<List<AmortizationEntry>, String>((ref, loanId) {
  final loans = ref.watch(loansProvider).valueOrNull ?? [];
  final loanList = loans.where((l) => l.id == loanId).toList();
  if (loanList.isEmpty) return [];
  final payments = ref.watch(loanPaymentsProvider(loanId)).valueOrNull ?? [];
  return ref.watch(loanServiceProvider).buildSchedule(loanList.first, payments);
});

// ── Computed: summary stats across all active loans ───────────────────────

class LoanSummary {
  final double totalOutstanding;
  final double totalMonthlyEmi;
  final int activeCount;
  const LoanSummary({
    required this.totalOutstanding,
    required this.totalMonthlyEmi,
    required this.activeCount,
  });
}

final loanSummaryProvider = Provider<LoanSummary>((ref) {
  final loans = ref.watch(loansProvider).valueOrNull ?? [];
  final active = loans.where((l) => l.status == LoanStatus.active).toList();
  double outstanding = 0;
  double monthlyEmi = 0;
  for (final loan in active) {
    final remaining = ref.watch(loanRemainingPrincipalProvider(loan.id));
    outstanding += remaining;
    monthlyEmi += loan.baseEmi;
  }
  return LoanSummary(
    totalOutstanding: outstanding,
    totalMonthlyEmi: monthlyEmi,
    activeCount: active.length,
  );
});
