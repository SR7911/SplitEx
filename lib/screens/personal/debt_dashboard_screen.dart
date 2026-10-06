import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_debt_sheet.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kBlue = Color(0xFF3B82F6);

class DebtDashboardScreen extends ConsumerWidget {
  const DebtDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(personalDebtsProvider);

    return Scaffold(
      appBar: AppHeader(
        showBack: true,
        title: 'Debt Dashboard',
        showNotification: false,
        trailing: IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: () => showAddDebtSheet(context),
          tooltip: 'Add Debt',
        ),
      ),
      body: GradientBody(
        child: debtsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allDebts) => _DashboardBody(allDebts: allDebts),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final List<PersonalTransactionModel> allDebts;
  const _DashboardBody({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    final lent = allDebts.where((t) => t.debtType == DebtType.lent).toList();
    final borrowed = allDebts.where((t) => t.debtType == DebtType.borrowed).toList();

    final totalLent = lent.where((t) => !t.isSettled).fold<double>(0, (s, t) => s + t.remainingAmount);
    final totalBorrowed = borrowed.where((t) => !t.isSettled).fold<double>(0, (s, t) => s + t.remainingAmount);
    final netBalance = totalLent - totalBorrowed;
    final activeCount = allDebts.where((t) => !t.isSettled).length;

    if (allDebts.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.handshake_outlined,
          title: 'No debts yet',
          subtitle: 'Track money you lent or borrowed',
          actionLabel: 'Add Debt',
          onAction: () => showAddDebtSheet(context),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: [
        _HeroCard(
          totalLent: totalLent,
          totalBorrowed: totalBorrowed,
          netBalance: netBalance,
          activeCount: activeCount,
        ),
        const SizedBox(height: 16),
        _QuickActions(allDebts: allDebts),
        const SizedBox(height: 20),
        _MonthlyChart(allDebts: allDebts),
        const SizedBox(height: 20),
        _BorrowedVsLentChart(totalLent: totalLent, totalBorrowed: totalBorrowed),
        const SizedBox(height: 20),
        _MostDebtedPeople(allDebts: allDebts),
        const SizedBox(height: 20),
        _TopDebtsSection(
          title: 'Top Lent Debts',
          icon: Icons.call_made,
          color: _kGreen,
          debts: lent.where((t) => !t.isSettled).toList()
            ..sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount)),
        ),
        const SizedBox(height: 20),
        _TopDebtsSection(
          title: 'Top Borrowed Debts',
          icon: Icons.call_received,
          color: _kRed,
          debts: borrowed.where((t) => !t.isSettled).toList()
            ..sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount)),
        ),
        const SizedBox(height: 20),
        _RecentDebts(allDebts: allDebts),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final double totalLent;
  final double totalBorrowed;
  final double netBalance;
  final int activeCount;
  const _HeroCard({
    required this.totalLent,
    required this.totalBorrowed,
    required this.netBalance,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = netBalance >= 0;
    final gradientColors = isPositive
        ? [const Color(0xFF059669), const Color(0xFF0D9488)]
        : [const Color(0xFFDC2626), const Color(0xFFDB2777)];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: gradientColors.first.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net Balance', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Text('$activeCount active', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${isPositive ? '+' : '-'}₹${netBalance.abs().toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.5),
          ),
          const SizedBox(height: 4),
          Text(
            isPositive ? 'Others owe you more' : 'You owe others more',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroChip(icon: Icons.call_made, label: 'Lent', value: '₹${totalLent.toStringAsFixed(0)}', color: _kGreen),
              const SizedBox(width: 10),
              _HeroChip(icon: Icons.call_received, label: 'Borrowed', value: '₹${totalBorrowed.toStringAsFixed(0)}', color: _kRed),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _HeroChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.65))),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final List<PersonalTransactionModel> allDebts;
  const _QuickActions({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionBtn(icon: Icons.add_rounded, label: 'Add Debt', color: _kGreen, onTap: () => showAddDebtSheet(context)),
        const SizedBox(width: 10),
        _ActionBtn(icon: Icons.list_alt_rounded, label: 'View All', color: _kBlue, onTap: () => context.push('/personal/debt-list')),
        const SizedBox(width: 10),
        _ActionBtn(icon: Icons.call_made, label: 'Lent', color: _kGreen, onTap: () => context.push('/personal/debts')),
        const SizedBox(width: 10),
        _ActionBtn(icon: Icons.call_received, label: 'Borrowed', color: _kRed, onTap: () => context.push('/personal/debts')),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Monthly Chart ──────────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final List<PersonalTransactionModel> allDebts;
  const _MonthlyChart({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build last 6 months
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      return DateFormat('yyyy-MM').format(d);
    });

    final lentByMonth = <String, double>{};
    final borrowedByMonth = <String, double>{};
    for (final m in months) {
      lentByMonth[m] = 0;
      borrowedByMonth[m] = 0;
    }
    for (final t in allDebts) {
      if (!months.contains(t.month)) continue;
      if (t.debtType == DebtType.lent) {
        lentByMonth[t.month] = (lentByMonth[t.month] ?? 0) + t.amount;
      } else {
        borrowedByMonth[t.month] = (borrowedByMonth[t.month] ?? 0) + t.amount;
      }
    }

    final maxVal = [...lentByMonth.values, ...borrowedByMonth.values].fold<double>(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Monthly Debt Activity', actionLabel: null, onAction: null),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                        final label = DateFormat('MMM').format(DateTime.parse('${months[idx]}-01'));
                        return Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withValues(alpha: 0.08), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(months.length, (i) {
                  final m = months[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: lentByMonth[m]!, color: _kGreen, width: 8, borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(toY: borrowedByMonth[m]!, color: _kRed, width: 8, borderRadius: BorderRadius.circular(4)),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Legend(color: _kGreen, label: 'Lent'),
              const SizedBox(width: 16),
              _Legend(color: _kRed, label: 'Borrowed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}

// ── Borrowed vs Lent Donut ─────────────────────────────────────────────────

class _BorrowedVsLentChart extends StatelessWidget {
  final double totalLent;
  final double totalBorrowed;
  const _BorrowedVsLentChart({required this.totalLent, required this.totalBorrowed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = totalLent + totalBorrowed;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Lent vs Borrowed', actionLabel: null, onAction: null),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100, height: 100,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 28,
                  sections: [
                    PieChartSectionData(value: totalLent, color: _kGreen, title: '', radius: 32),
                    PieChartSectionData(value: totalBorrowed, color: _kRed, title: '', radius: 32),
                  ],
                )),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChartLegendRow(color: _kGreen, label: 'You Lent', amount: totalLent, total: total),
                    const SizedBox(height: 12),
                    _ChartLegendRow(color: _kRed, label: 'You Borrowed', amount: totalBorrowed, total: total),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final double total;
  const _ChartLegendRow({required this.color, required this.label, required this.amount, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = total > 0 ? (amount / total * 100).toInt() : 0;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)))),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Text('$pct%', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
      ],
    );
  }
}

// ── Most Debted People ─────────────────────────────────────────────────────

class _MostDebtedPeople extends ConsumerWidget {
  final List<PersonalTransactionModel> allDebts;
  const _MostDebtedPeople({required this.allDebts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final balances = ref.watch(personalDebtBalancesProvider);
    if (balances.isEmpty) return const SizedBox.shrink();

    final sorted = balances.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final top = sorted.take(5).toList();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Most Debted People', actionLabel: null, onAction: null),
          const SizedBox(height: 14),
          ...top.map((e) {
            final isPositive = e.value >= 0;
            final color = isPositive ? _kGreen : _kRed;
            final label = isPositive ? 'owes you' : 'you owe';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(e.key[0].toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : '-'}₹${e.value.abs().toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Top Debts Section ──────────────────────────────────────────────────────

class _TopDebtsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<PersonalTransactionModel> debts;
  const _TopDebtsSection({required this.title, required this.icon, required this.color, required this.debts});

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final top = debts.take(3).toList();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title, actionLabel: null, onAction: null),
          const SizedBox(height: 14),
          ...top.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.personName ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(t.title, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(DateFormat('dd MMM yyyy').format(t.date), style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
                Text('₹${t.remainingAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Recent Debts ───────────────────────────────────────────────────────────

class _RecentDebts extends StatelessWidget {
  final List<PersonalTransactionModel> allDebts;
  const _RecentDebts({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recent = [...allDebts]
      ..sort((a, b) => b.date.compareTo(a.date));
    final top = recent.take(5).toList();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Recent Debts',
            actionLabel: 'View All',
            onAction: () => context.push('/personal/debt-list'),
          ),
          const SizedBox(height: 14),
          if (top.isEmpty)
            AppEmptyState(icon: Icons.handshake_outlined, title: 'No debts yet')
          else
            ...top.map((t) {
              final isLent = t.debtType == DebtType.lent;
              final color = isLent ? _kGreen : _kRed;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withValues(alpha: 0.1),
                      child: Icon(isLent ? Icons.call_made : Icons.call_received, size: 14, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.personName ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(t.title, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${t.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                        Text(DateFormat('dd MMM').format(t.date), style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
