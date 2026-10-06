import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/screens/loans/add_loan_sheet.dart';
import 'package:split_ex/screens/loans/loan_list_screen.dart'
    show loanStatusLabel, fmtAmount, LoanReportSheet, loanStatusColor;
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen  = Color(0xFF22C55E);
const _kBlue   = Color(0xFF3B82F6);
const _kAmber  = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF97316);

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    return loansAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (loans) {
        final match = loans.where((l) => l.id == loanId).toList();
        if (match.isEmpty) {
          return const Scaffold(
            appBar: AppHeader(showBack: true, title: 'Loan Detail', showNotification: false),
            body: Center(child: Text('Loan not found')),
          );
        }
        return _LoanDetailView(loan: match.first);
      },
    );
  }
}

class _LoanDetailView extends ConsumerStatefulWidget {
  final LoanModel loan;
  const _LoanDetailView({required this.loan});

  @override
  ConsumerState<_LoanDetailView> createState() => _LoanDetailViewState();
}

class _LoanDetailViewState extends ConsumerState<_LoanDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // tabs: Overview | Reports | Schedule (borrowed only)
    _tabController = TabController(
      length: widget.loan.loanType == LoanType.borrowed ? 3 : 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, LoanModel loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: Text('Delete "${loan.title}" and all payment history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(loanServiceProvider).deleteLoan(userId, loan.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loan          = widget.loan;
    final remaining     = ref.watch(loanRemainingPrincipalProvider(loan.id));
    final emiProgress   = ref.watch(loanEmiProgressProvider(loan.id));
    final paymentsAsync = ref.watch(loanPaymentsProvider(loan.id));
    final schedule      = ref.watch(loanScheduleProvider(loan.id));
    final isActive      = loan.status == LoanStatus.active;
    final progress      = 1 - (remaining / loan.principal).clamp(0.0, 1.0);
    final cs            = Theme.of(context).colorScheme;
    final statusColor   = loanStatusColor(loan.status, cs.primary);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(loan.title),
        leading: const BackButton(),
        flexibleSpace: _AppBarGradient(),
        actions: [
          if (isActive)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showAddLoanSheet(context, existing: loan),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'delete') _showDeleteDialog(context, ref, loan);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete Loan', style: TextStyle(color: Colors.red, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Reports'),
            if (loan.loanType == LoanType.borrowed) const Tab(text: 'Schedule'),
          ],
        ),
      ),
      body: GradientBody(child: TabBarView(
        controller: _tabController,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _HeroCard(loan: loan, remaining: remaining, progress: progress, statusColor: statusColor, emiProgress: emiProgress),
              const SizedBox(height: 16),
              if (isActive) _ActionButtons(loan: loan, remaining: remaining),
              if (isActive) const SizedBox(height: 20),
              _PaymentHistory(paymentsAsync: paymentsAsync),
            ],
          ),
          // Reports tab — reuses LoanReportSheet content as a scrollable page
          _ReportsTab(loan: loan),
          if (loan.loanType == LoanType.borrowed)
            _AmortizationTab(schedule: schedule, loan: loan),
        ],
      )),
    );
  }
}

class _AppBarGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withValues(alpha: isDark ? 0.55 : 0.45),
            primary.withValues(alpha: 0.18),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final LoanModel loan;
  final double remaining;
  final double progress;
  final Color statusColor;
  final LoanEmiProgress emiProgress;
  const _HeroCard({required this.loan, required this.remaining, required this.progress, required this.statusColor, required this.emiProgress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLent = loan.loanType == LoanType.lent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [statusColor.withValues(alpha: 0.85), statusColor.withValues(alpha: 0.55)]
              : [statusColor, statusColor.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.2 : 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Stack(
          children: [
            Positioned(
              top: -30, right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loanStatusLabel(loan.status),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLent ? 'I Lent' : 'I Borrowed',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (loan.lenderBorrowerName != null)
                  Text(
                    loan.lenderBorrowerName!,
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                const SizedBox(height: 4),
                Text(
                  '₹${fmtAmount(remaining)}',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.0),
                ),
                Text(
                  'remaining of ₹${fmtAmount(loan.principal)}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% paid',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                    ),
                    if (loan.loanType == LoanType.borrowed)
                      Text(
                        'EMI ₹${loan.baseEmi.toStringAsFixed(0)} · ${emiProgress.paidCount}/${emiProgress.totalCount} paid'
                        '${emiProgress.nextDueDate != null ? ' · Next: ${DateFormat('dd MMM').format(emiProgress.nextDueDate!)}' : ''}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                      )
                    else
                      Text(
                        'Tenure ${loan.tenureMonths}m · Ends ${DateFormat('MMM yy').format(loan.endDate)}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _InfoChip(label: 'Rate', value: '${loan.annualInterestRate}%'),
                    const SizedBox(width: 8),
                    _InfoChip(label: 'Tenure', value: '${loan.tenureMonths}m'),
                    const SizedBox(width: 8),
                    _InfoChip(label: 'End', value: DateFormat('MMM yy').format(loan.endDate)),
                  ],
                ),
                if (loan.totalCharges > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: 6),
                        Text(
                          'Charges: ₹${fmtAmount(loan.totalCharges)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                        const Spacer(),
                        Text(
                          'Net disbursed: ₹${fmtAmount(loan.netDisbursed)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final LoanModel loan;
  final double remaining;
  const _ActionButtons({required this.loan, required this.remaining});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLent = loan.loanType == LoanType.lent;

    if (isLent) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showPartialPaymentDialog(context, ref),
              icon: const Icon(Icons.call_received_rounded, size: 18),
              label: const Text('Record Repayment'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _DangerButton(onPressed: () => _showForecloseDialog(context, ref)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showLogEmiDialog(context, ref),
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('Log EMI'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showPartialPaymentDialog(context, ref),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('Prepay'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _DangerButton(onPressed: () => _showForecloseDialog(context, ref)),
      ],
    );
  }

  void _showLogEmiDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log EMI Payment'),
        content: Text('Log EMI of ₹${loan.baseEmi.toStringAsFixed(0)} for today?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(loanServiceProvider).logEmiPayment(userId, loan.id, remaining, DateTime.now());
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMI logged')));
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showPartialPaymentDialog(BuildContext context, WidgetRef ref) {
    final isLent   = loan.loanType == LoanType.lent;
    final ctrl     = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLent ? 'Record Repayment' : 'Partial Prepayment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0 || amount > remaining) return;
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(loanServiceProvider).logPartialPayment(
                userId, loan.id, remaining, amount, DateTime.now(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              );
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isLent ? 'Repayment recorded' : 'Partial payment logged')),
              );
            },
            child: Text(isLent ? 'Record' : 'Log'),
          ),
        ],
      ),
    );
  }

  void _showForecloseDialog(BuildContext context, WidgetRef ref) {
    final isLent = loan.loanType == LoanType.lent;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLent ? 'Write Off Loan' : 'Force Close Loan'),
        content: Text(
          isLent
              ? 'This will write off the remaining ₹${remaining.toStringAsFixed(0)} and mark the loan as closed.'
              : 'This will pay off the remaining ₹${remaining.toStringAsFixed(0)} + accrued interest and mark the loan as Foreclosed. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(loanServiceProvider).forecloseLoan(userId, loan.id, remaining);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isLent ? 'Loan written off' : 'Loan foreclosed')),
              );
            },
            child: Text(isLent ? 'Write Off' : 'Foreclose'),
          ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DangerButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: _kRed,
        side: const BorderSide(color: _kRed),
      ),
      child: const Icon(Icons.close_rounded, size: 18),
    );
  }
}

class _PaymentHistory extends StatelessWidget {
  final AsyncValue<List<LoanPaymentModel>> paymentsAsync;
  const _PaymentHistory({required this.paymentsAsync});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Payment History', actionLabel: null, onAction: null),
          const SizedBox(height: 14),
          paymentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (payments) {
              if (payments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No payments yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45))),
                  ),
                );
              }
              return Column(
                children: payments.asMap().entries.map((entry) {
                  final p      = entry.value;
                  final isLast = entry.key == payments.length - 1;
                  final typeColor = p.type == PaymentType.foreclosure
                      ? _kRed
                      : p.type == PaymentType.partial
                          ? _kOrange
                          : _kGreen;
                  final typeLabel = p.type == PaymentType.foreclosure
                      ? 'Foreclosure'
                      : p.type == PaymentType.partial
                          ? 'Partial'
                          : 'EMI';
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: isDark ? 0.07 : 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: typeColor.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(Icons.payment_rounded, size: 18, color: typeColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '₹${p.amount.toStringAsFixed(0)}',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                                        ),
                                        child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Principal ₹${p.principalComponent.toStringAsFixed(0)} · Interest ₹${p.interestComponent.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yy').format(p.date),
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AmortizationTab extends StatelessWidget {
  final List<AmortizationEntry> schedule;
  final LoanModel loan;
  const _AmortizationTab({required this.schedule, required this.loan});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (schedule.isEmpty) {
      return const Center(child: Text('No schedule available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: schedule.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _HeaderCell('Month', flex: 1),
                _HeaderCell('EMI', flex: 2),
                _HeaderCell('Principal', flex: 2),
                _HeaderCell('Interest', flex: 2),
                _HeaderCell('Balance', flex: 2),
              ],
            ),
          );
        }
        final entry  = schedule[index - 1];
        final isPaid = entry.isPaid;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isPaid
                ? _kGreen.withValues(alpha: isDark ? 0.08 : 0.05)
                : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPaid ? _kGreen.withValues(alpha: 0.2) : cs.outline.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.month}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPaid ? _kGreen : cs.onSurface),
                    ),
                    Text(
                      DateFormat('MMM yy').format(entry.dueDate),
                      style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              _Cell('₹${entry.emi.toStringAsFixed(0)}', flex: 2, bold: true),
              _Cell('₹${entry.principal.toStringAsFixed(0)}', flex: 2, color: _kBlue),
              _Cell('₹${entry.interest.toStringAsFixed(0)}', flex: 2, color: _kAmber),
              _Cell('₹${entry.remainingPrincipal.toStringAsFixed(0)}', flex: 2),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;
  const _Cell(this.text, {required this.flex, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ── Reports Tab ───────────────────────────────────────────────────────────
// Embeds the same pie + bar chart content from LoanReportSheet as a full tab.

class _ReportsTab extends ConsumerWidget {
  final LoanModel loan;
  const _ReportsTab({required this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Delegate entirely to LoanReportSheet's body by embedding it in a
    // scrollable page — we strip the sheet handle/header since the AppBar
    // already shows the loan title.
    return LoanReportSheet(loan: loan, embeddedMode: true);
  }
}
