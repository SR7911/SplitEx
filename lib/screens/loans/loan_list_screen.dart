import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/screens/loans/add_loan_sheet.dart';
import 'package:split_ex/services/loan_service.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

// ── Shared helpers ────────────────────────────────────────────────────────

Color loanStatusColor(LoanStatus s, [Color? primary]) => switch (s) {
      LoanStatus.active => primary ?? const Color(0xFF3B82F6),
      LoanStatus.settled => const Color(0xFF22C55E),
      LoanStatus.foreclosed => const Color(0xFFF59E0B),
    };

String loanStatusLabel(LoanStatus s) => switch (s) {
      LoanStatus.active => 'Active',
      LoanStatus.settled => 'Settled',
      LoanStatus.foreclosed => 'Foreclosed',
    };

String fmtAmount(double v) => NumberFormat('#,##,###').format(v.round());

String fmtCompact(double v) {
  if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
  return '₹${v.toStringAsFixed(0)}';
}

const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kIndigo = Color(0xFF6366F1);
const _kTeal   = Color(0xFF14B8A6);

// ── Screen ────────────────────────────────────────────────────────────────

class LoanListScreen extends ConsumerWidget {
  const LoanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    final summary    = ref.watch(loanSummaryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const AppHeader(
        showBack: true,
        title: 'Loans & EMI',
        showNotification: false,
      ),
      body: GradientBody(child: loansAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.base),
          itemCount: 5,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: i == 0
                ? AppLoadingShimmer.block(height: 200)
                : AppLoadingShimmer.block(height: 88),
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (loans) {
          if (loans.isEmpty) {
            return AppEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No loans tracked yet',
              subtitle: 'Add a loan to track EMIs, amortization, and payments',
              actionLabel: 'Add Loan',
              onAction: () => showAddLoanSheet(context),
            );
          }

          final active = loans.where((l) => l.status == LoanStatus.active).toList();
          final closed = loans.where((l) => l.status != LoanStatus.active).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              _LoansHeader(),
              const SizedBox(height: 20),
              _LoansHeroCard(summary: summary, loans: loans),
              const SizedBox(height: 16),
              _LoansMiniStatRow(summary: summary),
              const SizedBox(height: 20),
              _LoansQuickActions(),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 20),
                AppSectionHeader(title: 'Active Loans (${active.length})', actionLabel: null, onAction: null),
                const SizedBox(height: 14),
                ...active.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key == active.length - 1 ? 0 : 10),
                  child: _LoanCard(loan: e.value),
                )),
              ],
              if (closed.isNotEmpty) ...[
                const SizedBox(height: 20),
                AppSectionHeader(title: 'Closed Loans (${closed.length})', actionLabel: null, onAction: null),
                const SizedBox(height: 14),
                ...closed.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key == closed.length - 1 ? 0 : 10),
                  child: _LoanCard(loan: e.value, muted: true),
                )),
              ],
            ],
          );
        },
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddLoanSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _LoansHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Loans',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Track EMIs, amortization & payments',
          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────

class _LoansHeroCard extends StatelessWidget {
  final LoanSummary summary;
  final List<LoanModel> loans;
  const _LoansHeroCard({required this.summary, required this.loans});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cs       = Theme.of(context).colorScheme;
    final primary  = cs.primary;
    final hasLoans = summary.activeCount > 0;

    final gradientColors = isDark
        ? [primary.withValues(alpha: 0.85), primary.withValues(alpha: 0.55)]
        : [primary, primary.withValues(alpha: 0.78)];

    final onCard      = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.85);

    final totalBorrowed = loans
        .where((l) => l.loanType == LoanType.borrowed)
        .fold<double>(0, (s, l) => s + l.principal);
    final totalLent = loans
        .where((l) => l.loanType == LoanType.lent)
        .fold<double>(0, (s, l) => s + l.principal);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: isDark ? 0.2 : 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(top: -40, right: -40, child: IgnorePointer(child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06))))),
            Positioned(bottom: -30, left: -30, child: IgnorePointer(child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))))),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.account_balance_rounded, size: 12, color: onCard),
                          const SizedBox(width: 5),
                          Text('Loans & EMI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onCard)),
                        ]),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          hasLoans ? '${summary.activeCount} Active' : 'No Active',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: onCard),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Total Outstanding', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onCardMuted, letterSpacing: 0.3)),
                  const SizedBox(height: 6),
                  Text(
                    fmtCompact(summary.totalOutstanding),
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1.5, height: 1.1),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AppHeroChip(icon: Icons.arrow_downward_rounded, label: 'Borrowed', value: fmtCompact(totalBorrowed), onCard: onCard, onCardMuted: onCardMuted),
                      const SizedBox(width: 10),
                      AppHeroChip(icon: Icons.arrow_upward_rounded,   label: 'Lent',     value: fmtCompact(totalLent),     onCard: onCard, onCardMuted: onCardMuted),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.payments_rounded, size: 16, color: onCard),
                          const SizedBox(height: 2),
                          Text(fmtCompact(summary.totalMonthlyEmi), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard)),
                          Text('EMI/mo', style: TextStyle(fontSize: 9, color: onCardMuted)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini stat row ─────────────────────────────────────────────────────────

class _LoansMiniStatRow extends StatelessWidget {
  final LoanSummary summary;
  const _LoansMiniStatRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppMiniStatCard(label: 'Active',      value: '${summary.activeCount}',              icon: Icons.account_balance_rounded, color: _kBlue)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Outstanding', value: fmtCompact(summary.totalOutstanding),  icon: Icons.trending_down_rounded,   color: _kIndigo)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Monthly EMI', value: fmtCompact(summary.totalMonthlyEmi),   icon: Icons.payments_rounded,        color: _kTeal)),
      ],
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────

class _LoansQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = _kGreen;
    return GestureDetector(
      onTap: () => showAddLoanSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20, color: color),
            const SizedBox(width: 8),
            Text('Add Loan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Loan card ─────────────────────────────────────────────────────────────

class _LoanCard extends ConsumerStatefulWidget {
  final LoanModel loan;
  final bool muted;
  const _LoanCard({required this.loan, this.muted = false});

  @override
  ConsumerState<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends ConsumerState<_LoanCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final remaining = ref.read(loanRemainingPrincipalProvider(widget.loan.id));
    final progress  = 1 - (remaining / widget.loan.principal).clamp(0.0, 1.0);
    _progressAnim   = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: Text('Delete "${widget.loan.title}" and all payment history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(loanServiceProvider).deleteLoan(userId, widget.loan.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRecurring(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring?'),
        content: const Text('This will delete the linked recurring EMI entry. The loan record will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null || widget.loan.recurringId == null) return;
              await ref.read(loanServiceProvider).deleteRecurring(userId, widget.loan.recurringId!);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmForceClose(BuildContext context, WidgetRef ref) {
    final remaining = ref.read(loanRemainingPrincipalProvider(widget.loan.id));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Close Loan?'),
        content: Text('Pay off remaining ₹${remaining.toStringAsFixed(0)} + accrued interest and mark as Foreclosed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(loanServiceProvider).forecloseLoan(userId, widget.loan.id, remaining);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan force closed')));
            },
            child: const Text('Force Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final loan        = widget.loan;
    final remaining   = ref.watch(loanRemainingPrincipalProvider(loan.id));
    final emiProgress = ref.watch(loanEmiProgressProvider(loan.id));
    final progress    = 1 - (remaining / loan.principal).clamp(0.0, 1.0);
    final statusColor = loanStatusColor(loan.status, cs.primary);
    final isLent      = loan.loanType == LoanType.lent;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_progressAnim.value - progress).abs() > 0.01) {
        _progressAnim = Tween<double>(begin: _progressAnim.value, end: progress).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
        );
        _ctrl..reset()..forward();
      }
    });

    return Opacity(
      opacity: widget.muted ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: () => context.push('/personal/loans/${loan.id}'),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: appCardDecoration(context, accentColor: statusColor),
          child: Stack(
            children: [
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.xl),
                      bottomLeft: Radius.circular(AppRadius.xl),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isLent ? Icons.call_made_rounded : Icons.account_balance_rounded,
                            size: 20, color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loan.title,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              if (loan.lenderBorrowerName != null)
                                Text(
                                  loan.lenderBorrowerName!,
                                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${fmtAmount(remaining)}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: statusColor),
                            ),
                            const SizedBox(height: 3),
                            _StatusBadge(status: loan.status),
                          ],
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (v) {
                            if (v == 'delete') _confirmDelete(context, ref);
                            if (v == 'delete_recurring') _confirmDeleteRecurring(context, ref);
                            if (v == 'force_close') _confirmForceClose(context, ref);
                          },
                          itemBuilder: (_) => [
                            if (loan.status == LoanStatus.active)
                              const PopupMenuItem(value: 'force_close', child: Row(children: [
                                Icon(Icons.close_rounded, size: 16, color: Color(0xFFF59E0B)),
                                SizedBox(width: 10),
                                Text('Force Close', style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B))),
                              ])),
                            if (loan.recurringId != null)
                              const PopupMenuItem(value: 'delete_recurring', child: Row(children: [
                                Icon(Icons.repeat_rounded, size: 16, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Delete Recurring', style: TextStyle(fontSize: 13, color: Colors.orange)),
                              ])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete Loan', style: TextStyle(fontSize: 13, color: Colors.red)),
                            ])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progressAnim.value,
                              minHeight: 6,
                              backgroundColor: cs.outline.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_progressAnim.value * 100).toStringAsFixed(0)}% paid',
                                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                              ),
                              Text(
                                '₹${fmtAmount(loan.principal - remaining)} of ₹${fmtAmount(loan.principal)}',
                                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (isLent) ...[
                          _FooterChip(icon: Icons.call_made_rounded, label: 'Lent ₹${fmtAmount(loan.principal)}'),
                        ] else ...[
                          _FooterChip(icon: Icons.payments_outlined,    label: 'EMI ₹${loan.baseEmi.toStringAsFixed(0)}'),
                          const SizedBox(width: 8),
                          _FooterChip(
                            icon: Icons.check_circle_outline_rounded,
                            label: '${emiProgress.paidCount}/${emiProgress.totalCount} EMIs',
                          ),
                        ],
                        const Spacer(),
                        if (!isLent && emiProgress.nextDueDate != null)
                          _FooterChip(
                            icon: Icons.event_rounded,
                            label: 'Next: ${DateFormat('dd MMM').format(emiProgress.nextDueDate!)}',
                          )
                        else
                          _FooterChip(
                            icon: Icons.schedule_rounded,
                            label: '${loan.tenureMonths}m · ${DateFormat('MMM yy').format(loan.endDate)}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LoanStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = loanStatusColor(status, Theme.of(context).colorScheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        loanStatusLabel(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FooterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Loan Report Bottom Sheet ──────────────────────────────────────────────

const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF97316);

// Public so loan_reports_screen can import it
class LoanReportSheet extends ConsumerWidget {
  final LoanModel loan;
  final bool embeddedMode;
  const LoanReportSheet({super.key, required this.loan, this.embeddedMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs        = Theme.of(context).colorScheme;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final remaining = ref.watch(loanRemainingPrincipalProvider(loan.id));
    final payments  = ref.watch(loanPaymentsProvider(loan.id)).valueOrNull ?? [];

    final principalPaid      = (loan.principal - remaining).clamp(0.0, loan.principal);
    final principalRemaining = remaining.clamp(0.0, loan.principal);

    // Compute total interest from payment history
    final totalInterestPaid = payments.fold<double>(0, (s, p) => s + p.interestComponent);

    // Estimate total interest over full tenure
    double totalInterestFull = 0;
    if (loan.annualInterestRate > 0) {
      final emi = loan.baseEmi;
      totalInterestFull = (emi * loan.tenureMonths) - loan.principal;
    }
    final interestRemaining = (totalInterestFull - totalInterestPaid).clamp(0.0, double.infinity);

    // Payment history sorted ascending (from start date)
    final sortedPayments = [...payments]..sort((a, b) => a.date.compareTo(b.date));

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        _LoanPieChart(
          principalPaid: principalPaid,
          principalRemaining: principalRemaining,
          interestPaid: totalInterestPaid,
          interestRemaining: interestRemaining,
        ),
        const SizedBox(height: 16),
        _PieLegend(
          principalPaid: principalPaid,
          principalRemaining: principalRemaining,
          interestPaid: totalInterestPaid,
          interestRemaining: interestRemaining,
          totalInterest: totalInterestFull,
          principal: loan.principal,
        ),
        const SizedBox(height: 20),
        _LoanBarChart(loan: loan, payments: payments),
        const SizedBox(height: 20),
        _ReportPaymentHistory(payments: sortedPayments),
      ],
    );

    // Embedded mode: plain scrollable page (used inside detail screen tab)
    if (embeddedMode) return content;

    // Sheet mode: fixed-height bottom sheet with handle + title header
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Loan Report · From ${DateFormat('dd MMM yyyy').format(loan.startDate)}',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                _ReportStatusBadge(status: loan.status),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: content),
        ],
      ),
    );
  }
}

// ── 3D-style Pie Chart ────────────────────────────────────────────────────

class _LoanPieChart extends StatefulWidget {
  final double principalPaid;
  final double principalRemaining;
  final double interestPaid;
  final double interestRemaining;
  const _LoanPieChart({
    required this.principalPaid,
    required this.principalRemaining,
    required this.interestPaid,
    required this.interestRemaining,
  });

  @override
  State<_LoanPieChart> createState() => _LoanPieChartState();
}

class _LoanPieChartState extends State<_LoanPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;

    final sections = [
      _buildSection(0, widget.principalPaid,      const Color(0xFF3B82F6), 'P.Paid'),
      _buildSection(1, widget.principalRemaining,  const Color(0xFF93C5FD), 'P.Rem'),
      _buildSection(2, widget.interestPaid,        const Color(0xFF22C55E), 'I.Paid'),
      _buildSection(3, widget.interestRemaining,   const Color(0xFFFCA5A5), 'I.Rem'),
    ].where((s) => s.value > 0).toList();

    if (sections.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data yet')));
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow layer for 3D effect
          Positioned(
            bottom: 8,
            child: Container(
              width: 160, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 20,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touched = response?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 52,
              sections: sections,
            ),
          ),
          // Center label
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${((widget.principalPaid / (widget.principalPaid + widget.principalRemaining).clamp(1, double.infinity)) * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
              ),
              Text('paid', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildSection(int index, double value, Color color, String label) {
    final isTouched = _touched == index;
    return PieChartSectionData(
      color: color,
      value: value,
      title: isTouched ? fmtCompact(value) : '',
      radius: isTouched ? 68 : 58,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      badgeWidget: isTouched
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
              ),
              child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      badgePositionPercentageOffset: 1.3,
    );
  }
}

// ── Pie Legend ────────────────────────────────────────────────────────────

class _PieLegend extends StatelessWidget {
  final double principalPaid;
  final double principalRemaining;
  final double interestPaid;
  final double interestRemaining;
  final double totalInterest;
  final double principal;
  const _PieLegend({
    required this.principalPaid,
    required this.principalRemaining,
    required this.interestPaid,
    required this.interestRemaining,
    required this.totalInterest,
    required this.principal,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _LegendItem(color: const Color(0xFF3B82F6), label: 'Principal Paid',      value: fmtCompact(principalPaid))),
            const SizedBox(width: 12),
            Expanded(child: _LegendItem(color: const Color(0xFF93C5FD), label: 'Principal Remaining', value: fmtCompact(principalRemaining))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _LegendItem(color: const Color(0xFF22C55E), label: 'Interest Paid',      value: fmtCompact(interestPaid))),
            const SizedBox(width: 12),
            Expanded(child: _LegendItem(color: const Color(0xFFFCA5A5), label: 'Interest Remaining', value: fmtCompact(interestRemaining))),
          ]),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Principal', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
              Text('₹${fmtAmount(principal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Interest (est.)', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
              Text('₹${fmtAmount(totalInterest)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10, height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Report Payment History ────────────────────────────────────────────────

class _ReportPaymentHistory extends StatelessWidget {
  final List<LoanPaymentModel> payments;
  const _ReportPaymentHistory({required this.payments});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment History',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No payments yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45))),
            ),
          )
        else
          ...payments.map((p) {
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
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: isDark ? 0.07 : 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.payment_rounded, size: 15, color: typeColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('₹${p.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                            ),
                            child: Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: typeColor)),
                          ),
                        ]),
                        Text(
                          'P: ₹${p.principalComponent.toStringAsFixed(0)}  I: ₹${p.interestComponent.toStringAsFixed(0)}',
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
            );
          }),
      ],
    );
  }
}

// ── Monthly Principal vs Interest Bar Chart ──────────────────────────────

class _LoanBarChart extends StatefulWidget {
  final LoanModel loan;
  final List<LoanPaymentModel> payments;
  const _LoanBarChart({required this.loan, required this.payments});

  @override
  State<_LoanBarChart> createState() => _LoanBarChartState();
}

class _LoanBarChartState extends State<_LoanBarChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build schedule to get per-month principal/interest split
    final service  = LoanService();
    final schedule = service.buildSchedule(widget.loan, widget.payments);
    if (schedule.isEmpty) return const SizedBox.shrink();

    // Show max 24 bars; if more, group by quarter
    final entries = schedule.length <= 24
        ? schedule
        : _sampleEvery(schedule, (schedule.length / 24).ceil());

    final maxVal = entries.fold<double>(
      0, (m, e) => (e.principal + e.interest) > m ? (e.principal + e.interest) : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Principal vs Interest',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 6),
        // Legend row
        Row(children: [
          _BarLegendDot(color: const Color(0xFF3B82F6), label: 'Principal'),
          const SizedBox(width: 16),
          _BarLegendDot(color: const Color(0xFFF59E0B), label: 'Interest'),
          const SizedBox(width: 16),
          _BarLegendDot(color: const Color(0xFF22C55E), label: 'Paid', isDot: false),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 230,
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
          ),
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => isDark
                      ? cs.surfaceContainerHigh
                      : cs.surfaceContainerHighest,
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final e = entries[group.x];
                    final label = rodIndex == 0
                        ? 'P: ₹${e.principal.toStringAsFixed(0)}'
                        : 'I: ₹${e.interest.toStringAsFixed(0)}';
                    return BarTooltipItem(
                      'Mo ${e.month}\n$label',
                      TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() {
                    _touched = response?.spot?.touchedBarGroupIndex ?? -1;
                  });
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (v, _) => Text(
                      fmtCompact(v),
                      style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (entries.length / 6).ceilToDouble().clamp(1, double.infinity),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                      return Text(
                        'M${entries[idx].month}',
                        style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.45)),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outline.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: entries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final isTouched = _touched == i;
                final opacity = isTouched ? 1.0 : (e.isPaid ? 0.55 : 1.0);
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: e.principal,
                      color: const Color(0xFF3B82F6).withValues(alpha: opacity),
                      width: entries.length > 12 ? 5 : 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: e.isPaid,
                        toY: e.principal,
                        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                      ),
                    ),
                    BarChartRodData(
                      toY: e.interest,
                      color: const Color(0xFFF59E0B).withValues(alpha: opacity),
                      width: entries.length > 12 ? 5 : 8,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                  barsSpace: 2,
                  showingTooltipIndicators: isTouched ? [0, 1] : [],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<AmortizationEntry> _sampleEvery(List<AmortizationEntry> list, int step) {
    final result = <AmortizationEntry>[];
    for (int i = 0; i < list.length; i += step) {
      result.add(list[i]);
    }
    return result;
  }
}

class _BarLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDot;
  const _BarLegendDot({required this.color, required this.label, this.isDot = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: isDot ? 8 : 16,
        height: 8,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDot ? 1.0 : 0.2),
          borderRadius: BorderRadius.circular(isDot ? 4 : 3),
          border: isDot ? null : Border.all(color: color.withValues(alpha: 0.5)),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6))),
    ]);
  }
}

class _ReportStatusBadge extends StatelessWidget {
  final LoanStatus status;
  const _ReportStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = loanStatusColor(status, Theme.of(context).colorScheme.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        loanStatusLabel(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
