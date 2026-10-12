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

// ── Computed: EMI progress (paid count, total, next due date) ────────────

class LoanEmiProgress {
  final int paidCount;
  final int totalCount;
  final DateTime? nextDueDate;
  const LoanEmiProgress({required this.paidCount, required this.totalCount, this.nextDueDate});
}

final loanEmiProgressProvider =
    Provider.family<LoanEmiProgress, String>((ref, loanId) {
  final loans = ref.watch(loansProvider).valueOrNull ?? [];
  final loanList = loans.where((l) => l.id == loanId).toList();
  if (loanList.isEmpty) return const LoanEmiProgress(paidCount: 0, totalCount: 0);
  final loan = loanList.first;
  final payments = ref.watch(loanPaymentsProvider(loanId)).valueOrNull ?? [];
  final paidCount = payments.where((p) => p.type == PaymentType.emi).length;
  final now = DateTime.now();
  DateTime? nextDue;
  for (int i = paidCount + 1; i <= loan.tenureMonths; i++) {
    final ref2 = loan.effectiveEmiStart;
    final rawMonth = ref2.month + i - 1;
    final y = ref2.year + (rawMonth - 1) ~/ 12;
    final mo = ((rawMonth - 1) % 12) + 1;
    final maxDay = DateTime(y, mo + 1, 0).day;
    final due = DateTime(y, mo, loan.emiDueDay.clamp(1, maxDay));
    if (!due.isBefore(now)) { nextDue = due; break; }
  }
  return LoanEmiProgress(paidCount: paidCount, totalCount: loan.tenureMonths, nextDueDate: nextDue);
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
