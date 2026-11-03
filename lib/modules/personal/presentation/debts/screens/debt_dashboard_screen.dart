import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/debts/screens/add_debt_sheet.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_widgets.dart';
import 'package:split_ex/modules/personal/presentation/debts/screens/personal_debts_screen.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_tally_section.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

// accent colors resolved per-widget from theme

const _kLent = Color(0xFF10B981);
const _kBorrowed = Color(0xFFF43F5E);

Color _lentColor(BuildContext context) => _kLent;

Color _borrowedColor(BuildContext context) => _kBorrowed;

/// Personal debt overview backed by domain debt transactions.
class DebtDashboardScreen extends ConsumerWidget {
  const DebtDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(personalDebtTransactionsProvider);

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddDebtSheet(context),
        tooltip: 'Add Debt',
        child: const Icon(Icons.add_rounded),
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
  final List<PersonalTransaction> allDebts;
  const _DashboardBody({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    final lent = allDebts.where((t) => t.debtType == DebtType.lent).toList();
    final borrowed = allDebts
        .where((t) => t.debtType == DebtType.borrowed)
        .toList();

    final totalLent = lent
        .where((t) => !t.isSettled)
        .fold<double>(0, (s, t) => s + t.remainingAmount);
    final totalBorrowed = borrowed
        .where((t) => !t.isSettled)
        .fold<double>(0, (s, t) => s + t.remainingAmount);
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
          debts: allDebts,
          totalLent: totalLent,
          totalBorrowed: totalBorrowed,
          netBalance: netBalance,
          activeCount: activeCount,
        ),
        DebtTallySection(debts: allDebts),
        const SizedBox(height: 16),
        _QuickActions(allDebts: allDebts),
        const SizedBox(height: 20),

        _MonthlyChart(allDebts: allDebts),
        const SizedBox(height: 20),
        _BorrowedVsLentChart(
          totalLent: totalLent,
          totalBorrowed: totalBorrowed,
          debts: allDebts,
        ),
        const SizedBox(height: 20),
        DebtInsights(debts: allDebts, includeDetails: false),
        const SizedBox(height: 20),
        _MostDebtedPeople(allDebts: allDebts),
        const SizedBox(height: 20),
        _TopDebtsSection(
          title: 'Top Lent Debts',
          icon: Icons.call_made,
          color: _lentColor(context),
          debts: lent.where((t) => !t.isSettled).toList()
            ..sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount)),
        ),
        const SizedBox(height: 20),
        _TopDebtsSection(
          title: 'Top Borrowed Debts',
          icon: Icons.call_received,
          color: _borrowedColor(context),
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
  final List<PersonalTransaction> debts;
  final double totalLent;
  final double totalBorrowed;
  final double netBalance;
  final int activeCount;
  const _HeroCard({
    required this.debts,
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
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Net Balance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => showDebtDetailsSheet(
                  context,
                  'Outstanding Debts',
                  debts.where((t) => !t.isSettled).toList(),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${isPositive ? '+' : '-'}₹${NumberFormat('#,##0').format(netBalance.abs())}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPositive
                ? 'Others owe you more · $activeCount active'
                : 'You owe others more · $activeCount active',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _HeroStatChip(
                  icon: Icons.call_made_rounded,
                  label: 'You Lent',
                  value: '₹${NumberFormat('#,##0').format(totalLent)}',
                  color: _lentColor(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroStatChip(
                  icon: Icons.call_received_rounded,
                  label: 'You Borrowed',
                  value: '₹${NumberFormat('#,##0').format(totalBorrowed)}',
                  color: _borrowedColor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _HeroStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final List<PersonalTransaction> allDebts;
  const _QuickActions({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: AppQuickActionTile(icon: Icons.calendar_month_rounded, label: 'Monthly', color: cs.primary, onTap: () => context.push('/personal/debt-list'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: AppQuickActionTile(icon: Icons.list_alt_rounded, label: 'All Debts', color: const Color(0xFF6366F1), onTap: () => context.push('/personal/debts'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: AppQuickActionTile(icon: Icons.call_made_rounded, label: 'Lent', color: _lentColor(context), onTap: () => context.push('/personal/debts'))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: AppQuickActionTile(icon: Icons.call_received_rounded, label: 'Borrowed', color: _borrowedColor(context), onTap: () => context.push('/personal/debts?tab=1'))),
      ],
    );
  }
}

// ── Monthly Chart ──────────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final List<PersonalTransaction> allDebts;
  const _MonthlyChart({required this.allDebts});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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

    final maxVal = [
      ...lentByMonth.values,
      ...borrowedByMonth.values,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Monthly Debt Activity',
            actionLabel: 'View All',
            onAction: () => showDebtDetailsSheet(context, 'Monthly Debt Activity', allDebts),
          ),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.25,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dt = DateTime.parse('${months[group.x]}-01');
                      final label = '${DateFormat('MMM yyyy').format(dt)}';
                      final type = rodIndex == 0 ? 'Lent' : 'Borrowed';
                      final amt = NumberFormat('#,##0').format(rod.toY);
                      return BarTooltipItem(
                        '$label\n$type: ₹$amt',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    },
                  ),
                ),
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
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM').format(DateTime.parse('${months[idx]}-01')),
                            style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        );
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
                  final lc = _lentColor(context);
                  final bc = _borrowedColor(context);
                  return BarChartGroupData(
                    x: i,
                    groupVertically: false,
                    barRods: [
                      BarChartRodData(toY: lentByMonth[m]!, color: lc, width: 9, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      BarChartRodData(toY: borrowedByMonth[m]!, color: bc, width: 9, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _ChartDot(color: _lentColor(context), label: 'Lent'),
              const SizedBox(width: AppSpacing.base),
              _ChartDot(color: _borrowedColor(context), label: 'Borrowed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}

// ── Borrowed vs Lent Donut ─────────────────────────────────────────────────

class _BorrowedVsLentChart extends StatelessWidget {
  final List<PersonalTransaction> debts;
  final double totalLent;
  final double totalBorrowed;
  const _BorrowedVsLentChart({
    required this.totalLent,
    required this.totalBorrowed,
    required this.debts,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalLent + totalBorrowed;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Lent vs Borrowed',
            actionLabel: 'View All',
            onAction: () => showDebtDetailsSheet(context, 'Outstanding Debts', debts.where((t) => !t.isSettled).toList()),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(value: totalLent, color: _lentColor(context), title: '', radius: 34),
                      PieChartSectionData(value: totalBorrowed, color: _borrowedColor(context), title: '', radius: 34),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PieLegendRow(color: _lentColor(context), label: 'You Lent', amount: totalLent, total: total),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalLent / total,
                        backgroundColor: _borrowedColor(context).withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(_lentColor(context)),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PieLegendRow(color: _borrowedColor(context), label: 'You Borrowed', amount: totalBorrowed, total: total),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalBorrowed / total,
                        backgroundColor: _lentColor(context).withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(_borrowedColor(context)),
                        minHeight: 5,
                      ),
                    ),
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

class _PieLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final double total;
  const _PieLegendRow({required this.color, required this.label, required this.amount, required this.total});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = total > 0 ? (amount / total * 100).toInt() : 0;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)))),
        Text('₹${NumberFormat('#,##0').format(amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Text('$pct%', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
      ],
    );
  }
}

// ── Most Debted People ─────────────────────────────────────────────────────

class _MostDebtedPeople extends StatelessWidget {
  final List<PersonalTransaction> allDebts;
  const _MostDebtedPeople({required this.allDebts});
  @override
  Widget build(BuildContext context) {
    final people = _groupPeople(allDebts.where((t) => !t.isSettled).toList());
    if (people.isEmpty) return const SizedBox.shrink();
    return DebtSectionCard(
      title: 'Most Debted People',
      onViewAll: () => showDebtPeopleSheet(context, allDebts),
      children: people
          .take(5)
          .map((items) => _personRow(context, items))
          .toList(),
    );
  }
}

class _TopDebtsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<PersonalTransaction> debts;
  const _TopDebtsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.debts,
  });
  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const SizedBox.shrink();
    return DebtSectionCard(
      title: title,
      onViewAll: () => showDebtDetailsSheet(context, title, debts),
      children: debts
          .take(3)
          .map((t) => DebtTile(txn: t, showActions: false, embedded: true))
          .toList(),
    );
  }
}

class _RecentDebts extends StatelessWidget {
  final List<PersonalTransaction> allDebts;
  const _RecentDebts({required this.allDebts});
  @override
  Widget build(BuildContext context) {
    final sorted = [...allDebts]..sort((a, b) => b.date.compareTo(a.date));
    return DebtSectionCard(
      title: 'Recent Debts',
      onViewAll: () => showDebtDetailsSheet(context, 'Recent Debts', sorted),
      children: sorted
          .take(5)
          .map((t) => DebtTile(txn: t, showActions: false, embedded: true))
          .toList(),
    );
  }
}

class DebtInsights extends StatelessWidget {
  final List<PersonalTransaction> debts;
  final bool includeDetails;
  final bool collapsibleCategories;
  const DebtInsights({
    super.key,
    required this.debts,
    this.includeDetails = true,
    this.collapsibleCategories = false,
  });
  @override
  Widget build(BuildContext context) {
    final categories = _groupCategories(debts);
    return Column(
      children: [
        if (collapsibleCategories)
          _ExpandableDebtCategories(debts: debts)
        else
          DebtSectionCard(
            title: 'Top Categories',
            onViewAll: () => showDebtCategorySheet(context, debts),
            children: categories.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No debt activity in this period',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ),
                  ]
                : categories
                      .take(3)
                      .map((items) => _categoryRow(context, items, debts))
                      .toList(),
          ),
        if (includeDetails && debts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MostDebtedPeople(allDebts: debts),
          for (final type in DebtType.values) ...[
            const SizedBox(height: 16),
            _TopDebtsSection(
              title: type == DebtType.lent
                  ? 'Top Lent Debts'
                  : 'Top Borrowed Debts',
              icon: type == DebtType.lent
                  ? Icons.call_made
                  : Icons.call_received,
              color: type == DebtType.lent ? _lentColor(context) : _borrowedColor(context),
              debts:
                  debts
                      .where((t) => !t.isSettled && t.debtType == type)
                      .toList()
                    ..sort(
                      (a, b) => b.remainingAmount.compareTo(a.remainingAmount),
                    ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ExpandableDebtCategories extends StatefulWidget {
  final List<PersonalTransaction> debts;
  const _ExpandableDebtCategories({required this.debts});

  @override
  State<_ExpandableDebtCategories> createState() =>
      _ExpandableDebtCategoriesState();
}

class _ExpandableDebtCategoriesState extends State<_ExpandableDebtCategories> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final categories = _groupCategories(widget.debts);
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: debtCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: _expanded ? 'Collapse categories' : 'Expand categories',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: AppSectionHeader(title: 'Top Categories'),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: cs.primary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_expanded || categories.isEmpty)
                    Text(
                      categories.isEmpty
                          ? 'No debt activity in this period'
                          : '${categories.length} ${categories.length == 1 ? 'category' : 'categories'} · ${_money(_amount(widget.debts))} total',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  if (_expanded)
                    for (int i = 0; i < categories.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _categoryRow(context, categories[i], widget.debts),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<List<PersonalTransaction>> _groupCategories(
  List<PersonalTransaction> debts,
) {
  final groups = <String, List<PersonalTransaction>>{};
  for (final debt in debts) {
    groups.putIfAbsent(debt.category, () => []).add(debt);
  }
  return groups.values.toList()
    ..sort((a, b) => _amount(b).compareTo(_amount(a)));
}

double _amount(List<PersonalTransaction> debts) =>
    debts.fold<double>(0, (sum, t) => sum + t.amount);
String _money(double amount) => '₹${NumberFormat('#,##0.##').format(amount)}';

Widget _categoryRow(
  BuildContext context,
  List<PersonalTransaction> items,
  List<PersonalTransaction> all,
) {
  final total = _amount(all);
  final share = total == 0 ? 0 : (_amount(items) / total * 100).round();
  return DebtInfoRow(
    icon: Icons.category_outlined,
    title: items.first.category,
    subtitle: '${items.length} ${items.length == 1 ? 'debt' : 'debts'}',
    value: _money(_amount(items)),
    detail: '$share% of total',
    onTap: () => showDebtDetailsSheet(context, items.first.category, items),
  );
}

List<List<PersonalTransaction>> _groupPeople(List<PersonalTransaction> debts) {
  final groups = <String, List<PersonalTransaction>>{};
  for (final debt in debts) {
    groups.putIfAbsent(debt.personName ?? 'Unknown', () => []).add(debt);
  }
  return groups.values.toList()
    ..sort((a, b) => _net(b).abs().compareTo(_net(a).abs()));
}

double _net(List<PersonalTransaction> items) => items
    .where((t) => !t.isSettled)
    .fold<double>(
      0,
      (sum, t) =>
          sum +
          (t.debtType == DebtType.lent
              ? t.remainingAmount
              : -t.remainingAmount),
    );

Widget _personRow(BuildContext context, List<PersonalTransaction> items) {
  final net = _net(items);
  final name = items.first.personName ?? 'Unknown';
  final lent = items
      .where((t) => !t.isSettled && t.debtType == DebtType.lent)
      .fold<double>(0, (s, t) => s + t.remainingAmount);
  final borrowed = items
      .where((t) => !t.isSettled && t.debtType == DebtType.borrowed)
      .fold<double>(0, (s, t) => s + t.remainingAmount);
  return DebtInfoRow(
    icon: Icons.person_outline_rounded,
    title: name,
    subtitle: 'Lent ${_money(lent)} · Borrowed ${_money(borrowed)}',
    value: _money(net.abs()),
    detail: net > 0
        ? 'owes you'
        : net < 0
        ? 'you owe'
        : 'balanced',
    color: net > 0
        ? AppColors.success(context)
        : net < 0
        ? AppColors.error(context)
        : Theme.of(context).colorScheme.primary,
    onTap: () => showDebtDetailsSheet(context, name, items),
  );
}

void showDebtCategorySheet(
  BuildContext context,
  List<PersonalTransaction> debts,
) {
  final groups = _groupCategories(debts);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DebtSheetFrame(
      title: 'Debt Categories',
      itemCount: groups.length,
      subtitle:
          '${groups.length} ${groups.length == 1 ? 'category' : 'categories'} · ${_money(_amount(debts))} total',
      icon: Icons.category_outlined,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _categoryRow(context, groups[index], debts),
      ),
    ),
  );
}

void showDebtPeopleSheet(
  BuildContext context,
  List<PersonalTransaction> debts,
) {
  final groups = _groupPeople(debts);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DebtSheetFrame(
      title: 'People & Balances',
      itemCount: groups.length,
      subtitle:
          '${groups.length} ${groups.length == 1 ? 'person' : 'people'} · Outstanding balances',
      icon: Icons.people_outline_rounded,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _personRow(context, groups[index]),
      ),
    ),
  );
}
