import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/screens/personal/add_loan_sheet.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

// ── Shared helpers ────────────────────────────────────────────────────────

Color loanStatusColor(LoanStatus s) => switch (s) {
      LoanStatus.active => const Color(0xFF3B82F6),
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
      appBar: const AppHeader(showBack: true, title: 'Loans & EMI', showNotification: false),
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

    // Theme-based gradient — no budget logic
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

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final loan        = widget.loan;
    final remaining   = ref.watch(loanRemainingPrincipalProvider(loan.id));
    final progress    = 1 - (remaining / loan.principal).clamp(0.0, 1.0);
    final statusColor = loanStatusColor(loan.status);
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
              // Left accent bar
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
                    // Top row: icon + title + status badge
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
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Animated progress bar
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
                    // Footer chips
                    Row(
                      children: [
                        if (isLent) ...[
                          _FooterChip(icon: Icons.call_made_rounded, label: 'Lent ₹${fmtAmount(loan.principal)}'),
                        ] else ...[
                          _FooterChip(icon: Icons.payments_outlined,    label: 'EMI ₹${loan.baseEmi.toStringAsFixed(0)}'),
                          const SizedBox(width: 8),
                          _FooterChip(icon: Icons.event_repeat_rounded, label: 'Due day ${loan.emiDueDay}'),
                        ],
                        const Spacer(),
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
    final color = loanStatusColor(status);
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
