import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/screens/loans/loan_list_screen.dart'
    show loanStatusColor, loanStatusLabel, fmtAmount, fmtCompact, LoanReportSheet;
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen  = Color(0xFF22C55E);
const _kBlue   = Color(0xFF3B82F6);
const _kAmber  = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
const _kOrange = Color(0xFFF97316);

// ── Screen ────────────────────────────────────────────────────────────────

class LoanReportsScreen extends ConsumerStatefulWidget {
  const LoanReportsScreen({super.key});

  @override
  ConsumerState<LoanReportsScreen> createState() => _LoanReportsScreenState();
}

class _LoanReportsScreenState extends ConsumerState<LoanReportsScreen> {
  LoanStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppHeader(
        showBack: true,
        title: 'Loan Reports',
        showNotification: false,
      ),
      body: GradientBody(
        child: loansAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppLoadingShimmer.block(height: 100),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (loans) {
            final filtered = _filter == null
                ? loans
                : loans.where((l) => l.status == _filter).toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryBar(loans: loans),
                      _FilterChips(
                        selected: _filter,
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                    ],
                  ),
                ),
                filtered.isEmpty
                    ? SliverFillRemaining(
                        child: AppEmptyState(
                          icon: Icons.assessment_outlined,
                          title: 'No loans found',
                          subtitle: _filter != null
                              ? 'No ${loanStatusLabel(_filter!).toLowerCase()} loans'
                              : 'Add a loan to see reports',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReportLoanCard(loan: filtered[i]),
                            ),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────

class _SummaryBar extends ConsumerWidget {
  final List<LoanModel> loans;
  const _SummaryBar({required this.loans});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active     = loans.where((l) => l.status == LoanStatus.active).length;
    final settled    = loans.where((l) => l.status == LoanStatus.settled).length;
    final foreclosed = loans.where((l) => l.status == LoanStatus.foreclosed).length;
    final totalPrincipal = loans.fold<double>(0, (s, l) => s + l.principal);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.45), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _SummaryChip(label: 'Total',      value: loans.length.toString(), color: cs.primary),
            const SizedBox(width: 8),
            _SummaryChip(label: 'Active',     value: active.toString(),       color: _kBlue),
            const SizedBox(width: 8),
            _SummaryChip(label: 'Settled',    value: settled.toString(),      color: _kGreen),
            const SizedBox(width: 8),
            _SummaryChip(label: 'Foreclosed', value: foreclosed.toString(),   color: _kAmber),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.account_balance_rounded, size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 5),
            Text('Total principal: ', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
            Text(fmtCompact(totalPrincipal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ]),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label,  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final LoanStatus? selected;
  final ValueChanged<LoanStatus?> onChanged;
  const _FilterChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _Chip(label: 'All',        active: selected == null,                       color: cs.primary, onTap: () => onChanged(null)),
          const SizedBox(width: 8),
          _Chip(label: 'Active',     active: selected == LoanStatus.active,          color: _kBlue,     onTap: () => onChanged(LoanStatus.active)),
          const SizedBox(width: 8),
          _Chip(label: 'Settled',    active: selected == LoanStatus.settled,         color: _kGreen,    onTap: () => onChanged(LoanStatus.settled)),
          const SizedBox(width: 8),
          _Chip(label: 'Foreclosed', active: selected == LoanStatus.foreclosed,      color: _kAmber,    onTap: () => onChanged(LoanStatus.foreclosed)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : color),
        ),
      ),
    );
  }
}

// ── Report loan card ──────────────────────────────────────────────────────

class _ReportLoanCard extends ConsumerWidget {
  final LoanModel loan;
  const _ReportLoanCard({required this.loan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs        = Theme.of(context).colorScheme;
    final remaining = ref.watch(loanRemainingPrincipalProvider(loan.id));
    final paid      = loan.principal - remaining;
    final progress  = (paid / loan.principal).clamp(0.0, 1.0);
    final statusColor = loanStatusColor(loan.status, cs.primary);
    final isLent    = loan.loanType == LoanType.lent;

    return GestureDetector(
      onTap: () => _showLoanReport(context),
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
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isLent ? Icons.call_made_rounded : Icons.account_balance_rounded,
                          size: 18, color: statusColor,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${fmtAmount(remaining)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                          const SizedBox(height: 3),
                          _StatusBadge(status: loan.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: cs.outline.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% paid',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                      Text(
                        '₹${fmtAmount(paid)} of ₹${fmtAmount(loan.principal)}',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!isLent) ...[
                        _FooterChip(icon: Icons.payments_outlined, label: 'EMI ₹${loan.baseEmi.toStringAsFixed(0)}'),
                        const SizedBox(width: 8),
                      ],
                      _FooterChip(icon: Icons.schedule_rounded, label: '${loan.tenureMonths}m · ${DateFormat('MMM yy').format(loan.endDate)}'),
                      const Spacer(),
                      Row(children: [
                        Text('Tap for Report', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                        Icon(Icons.chevron_right_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
                      ]),
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

  void _showLoanReport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoanReportSheet(loan: loan),
    );
  }
}

// ── Amortization bottom sheet ─────────────────────────────────────────────

class _AmortizationSheet extends StatefulWidget {
  final LoanModel loan;
  final List<AmortizationEntry> schedule;
  final List<LoanPaymentModel> payments;
  const _AmortizationSheet({required this.loan, required this.schedule, required this.payments});

  @override
  State<_AmortizationSheet> createState() => _AmortizationSheetState();
}

class _AmortizationSheetState extends State<_AmortizationSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: widget.loan.loanType == LoanType.borrowed ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loan   = widget.loan;
    final isBorrowed = loan.loanType == LoanType.borrowed;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
          const SizedBox(height: 16),
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
                      if (loan.lenderBorrowerName != null)
                        Text(
                          loan.lenderBorrowerName!,
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),
                _StatusBadge(status: loan.status),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isBorrowed)
            TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Schedule'), Tab(text: 'Payment History')],
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Payment History',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: isBorrowed
                ? TabBarView(
                    controller: _tabs,
                    children: [
                      _ScheduleTab(schedule: widget.schedule),
                      _PaymentHistoryTab(payments: widget.payments),
                    ],
                  )
                : _PaymentHistoryTab(payments: widget.payments),
          ),
        ],
      ),
    );
  }
}

// ── Schedule tab ──────────────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  final List<AmortizationEntry> schedule;
  const _ScheduleTab({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (schedule.isEmpty) {
      return const Center(child: Text('No schedule available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: schedule.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              _H('Mo',        flex: 1),
              _H('EMI',       flex: 2),
              _H('Principal', flex: 2),
              _H('Interest',  flex: 2),
              _H('Balance',   flex: 2),
            ]),
          );
        }
        final e = schedule[index - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: e.isPaid
                ? _kGreen.withValues(alpha: isDark ? 0.08 : 0.05)
                : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: e.isPaid ? _kGreen.withValues(alpha: 0.2) : cs.outline.withValues(alpha: 0.06),
            ),
          ),
          child: Row(children: [
            Expanded(
              flex: 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${e.month}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: e.isPaid ? _kGreen : cs.onSurface),
                ),
                Text(
                  DateFormat('MMM yy').format(e.dueDate),
                  style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ]),
            ),
            _C('₹${e.emi.toStringAsFixed(0)}',               flex: 2, bold: true),
            _C('₹${e.principal.toStringAsFixed(0)}',          flex: 2, color: _kBlue),
            _C('₹${e.interest.toStringAsFixed(0)}',           flex: 2, color: _kAmber),
            _C('₹${e.remainingPrincipal.toStringAsFixed(0)}', flex: 2),
          ]),
        );
      },
    );
  }
}

// ── Payment history tab ───────────────────────────────────────────────────

class _PaymentHistoryTab extends StatelessWidget {
  final List<LoanPaymentModel> payments;
  const _PaymentHistoryTab({required this.payments});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (payments.isEmpty) {
      return Center(
        child: Text('No payments yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45))),
      );
    }

    final sorted = [...payments]..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final p = sorted[i];
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: typeColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.payment_rounded, size: 16, color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        '₹${p.amount.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                      ),
                    ]),
                    const SizedBox(height: 2),
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
      },
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────

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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _H extends StatelessWidget {
  final String t;
  final int flex;
  const _H(this.t, {required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          t,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
}

class _C extends StatelessWidget {
  final String t;
  final int flex;
  final bool bold;
  final Color? color;
  const _C(this.t, {required this.flex, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
}
