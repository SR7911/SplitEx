import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/presentation/providers/bill_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/expense_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/shared/ui/design_system/app_colors.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';

const _kPalette = [
  Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF59E0B),
  Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF8B5CF6),
  Color(0xFF3B82F6), Color(0xFFEC4899),
];
const _kIndigo = Color(0xFF6366F1);
const _kTeal   = Color(0xFF14B8A6);
const _kAmber  = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
const _kGreen  = Color(0xFF22C55E);
const _kPurple = Color(0xFF8B5CF6);

String _fmt(double v) => '₹${NumberFormat('#,##0', 'en_IN').format(v.round())}';

class AnalyticsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final DateTime? selectedMonth;
  const AnalyticsScreen({super.key, required this.roomId, this.selectedMonth});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = widget.selectedMonth ?? DateTime.now();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_month);

  bool get _isCurrentMonth =>
      _month.year == DateTime.now().year &&
      _month.month == DateTime.now().month;

  void _prev() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _next() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(
      monthExpensesProvider(MonthRoomKey(roomId: widget.roomId, month: _monthKey)),
    );
    final billsAsync = ref.watch(
      billsStreamProvider(MonthBillKey(roomId: widget.roomId, month: _monthKey)),
    );
    final userId = ref.watch(currentUserIdProvider);
    final room = ref.watch(roomStreamProvider(widget.roomId)).valueOrNull;

    return Scaffold(
      appBar: AppHeader(
        showBack: true,
        title: _isCurrentMonth
            ? 'Analytics'
            : 'Analytics · ${DateFormat('MMM yyyy').format(_month)}',
        showNotification: false,
      ),
      body: GradientBody(
        child: Column(
          children: [
            // Month selector
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.md, AppSpacing.base, 0,
              ),
              child: AppMonthSelector(
                selectedMonth: _month,
                onPrev: _prev,
                onNext: _next,
              ),
            ),
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (expenses) {
                  final bills = billsAsync.valueOrNull ?? [];
                  return _AnalyticsBody(
                    expenses: expenses,
                    bills: bills,
                    userId: userId,
                    month: _month,
                    monthKey: _monthKey,
                    roomId: widget.roomId,
                    memberIds: room?.memberIds ?? [],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _AnalyticsBody extends ConsumerWidget {
  final List<ExpenseModel> expenses;
  final List<BillModel> bills;
  final String userId;
  final DateTime month;
  final String monthKey;
  final String roomId;
  final List<String> memberIds;

  const _AnalyticsBody({
    required this.expenses,
    required this.bills,
    required this.userId,
    required this.month,
    required this.monthKey,
    required this.roomId,
    required this.memberIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIds = {...memberIds, ...expenses.map((e) => e.paidBy)}.toList();
    final profilesAsync = ref.watch(userProfilesByIdsProvider(allIds));
    final nameMap = <String, String>{};
    if (profilesAsync.hasValue) {
      for (final p in profilesAsync.value!) nameMap[p.uid] = p.name;
    }

    if (expenses.isEmpty && bills.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No data to analyze',
        subtitle: 'Add expenses or bills to see analytics for this month',
      );
    }

    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final totalBills = bills.fold<double>(0, (s, b) => s + b.amount);
    final grandTotal = totalExpenses + totalBills;

    // Category totals
    final catTotals = <String, double>{};
    for (final e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final catEntries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Per-member paid totals
    final memberPaid = <String, double>{};
    for (final e in expenses) {
      memberPaid[e.paidBy] = (memberPaid[e.paidBy] ?? 0) + e.amount;
    }
    for (final b in bills) {
      memberPaid[b.paidBy] = (memberPaid[b.paidBy] ?? 0) + b.amount;
    }
    final memberEntries = memberPaid.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Daily totals for bar chart
    final dailyTotals = <int, double>{};
    for (final e in expenses) {
      dailyTotals[e.date.day] = (dailyTotals[e.date.day] ?? 0) + e.amount;
    }
    final days = dailyTotals.keys.toList()..sort();
    final maxY = dailyTotals.values.fold<double>(0, (a, b) => a > b ? a : b);

    // Bill type breakdown
    final billTypeTotals = <BillType, double>{};
    for (final b in bills) {
      billTypeTotals[b.type] = (billTypeTotals[b.type] ?? 0) + b.amount;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.md, AppSpacing.base, 100,
      ),
      children: [
        // ── Summary banner ──
        _SummaryBanner(
          totalExpenses: totalExpenses,
          totalBills: totalBills,
          grandTotal: grandTotal,
          expenseCount: expenses.length,
          billCount: bills.length,
        ),
        const SizedBox(height: AppSpacing.base),

        // ── Category breakdown ──
        if (catEntries.isNotEmpty) ...[
          AppSectionHeader(title: 'By Category'),
          const SizedBox(height: AppSpacing.sm),
          _PieSection(
            entries: catEntries,
            total: totalExpenses,
          ),
          const SizedBox(height: AppSpacing.xs),
          ...catEntries.asMap().entries.map((e) => _ProgressBar(
            label: e.value.key,
            amount: e.value.value,
            total: totalExpenses,
            color: _kPalette[e.key % _kPalette.length],
          )),
          const SizedBox(height: AppSpacing.base),
        ],

        // ── Bills breakdown ──
        if (billTypeTotals.isNotEmpty) ...[
          AppSectionHeader(title: 'Bills'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: appCardDecoration(context),
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              children: billTypeTotals.entries.map((e) {
                final icon = switch (e.key) {
                  BillType.rent => Icons.home_rounded,
                  BillType.electricity => Icons.bolt_rounded,
                  BillType.water => Icons.water_drop_rounded,
                };
                final color = switch (e.key) {
                  BillType.rent => _kIndigo,
                  BillType.electricity => _kAmber,
                  BillType.water => _kTeal,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        e.key.name[0].toUpperCase() + e.key.name.substring(1),
                        style: AppTextStyles.bodySmall(context),
                      ),
                    ),
                    Text(
                      _fmt(e.value),
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: color,
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        // ── Who paid most ──
        if (memberEntries.isNotEmpty) ...[
          AppSectionHeader(title: 'Who Paid Most'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: appCardDecoration(context),
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              children: memberEntries.asMap().entries.map((entry) {
                final idx = entry.key;
                final id = entry.value.key;
                final amount = entry.value.value;
                final color = _kPalette[idx % _kPalette.length];
                final name = nameMap[id] ?? id;
                final pct = grandTotal > 0 ? amount / grandTotal : 0.0;
                final isMe = id == userId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: color.withValues(alpha: .15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isMe ? '$name (you)' : name,
                            style: AppTextStyles.bodySmall(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _fmt(amount),
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: color,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '${(pct * 100).round()}%',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: color,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: AppColors.border(context),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        // ── Daily spending chart ──
        if (days.isNotEmpty) ...[
          AppSectionHeader(title: 'Daily Spending'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: appCardDecoration(context),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.base, AppSpacing.md, AppSpacing.sm,
            ),
            child: SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.25,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(v.toInt().toString(),
                            style: const TextStyle(fontSize: 9)),
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                        _fmt(rod.toY),
                        const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  barGroups: days.map((day) => BarChartGroupData(
                    x: day,
                    barRods: [
                      BarChartRodData(
                        toY: dailyTotals[day]!,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.sm - 4),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_kTeal, _kTeal.withValues(alpha: .65)],
                        ),
                      ),
                    ],
                  )).toList(),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── _SummaryBanner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final double totalExpenses, totalBills, grandTotal;
  final int expenseCount, billCount;
  const _SummaryBanner({
    required this.totalExpenses,
    required this.totalBills,
    required this.grandTotal,
    required this.expenseCount,
    required this.billCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _kIndigo.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: _kIndigo, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Spending', style: AppTextStyles.caption(context)),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(grandTotal),
                    style: AppTextStyles.statSmall(context).copyWith(color: _kIndigo),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$expenseCount expenses', style: AppTextStyles.caption(context)),
                const SizedBox(height: 2),
                Text('$billCount bills', style: AppTextStyles.caption(context)),
              ],
            ),
          ]),
          if (totalBills > 0) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              _BannerChip(label: 'Expenses', value: _fmt(totalExpenses), color: _kPurple),
              const SizedBox(width: AppSpacing.sm),
              _BannerChip(label: 'Bills', value: _fmt(totalBills), color: _kAmber),
            ]),
          ],
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BannerChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: .15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption(context)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: color,
            )),
          ],
        ),
      ),
    );
  }
}

// ── _PieSection ───────────────────────────────────────────────────────────────

class _PieSection extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final double total;
  const _PieSection({required this.entries, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110, height: 110,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: entries.asMap().entries.map((e) => PieChartSectionData(
                value: e.value.value,
                color: _kPalette[e.key % _kPalette.length],
                title: '',
                radius: 36,
              )).toList(),
            )),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.take(6).map((entry) {
                final idx = entries.indexOf(entry);
                final pct = total > 0 ? (entry.value / total * 100).round() : 0;
                final color = _kPalette[idx % _kPalette.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(entry.key,
                        style: AppTextStyles.bodySmall(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                      ),
                      child: Text('$pct%',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600, color: color,
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ProgressBar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final String label;
  final double amount, total;
  final Color color;
  const _ProgressBar({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? amount / total : 0.0;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: appCardDecoration(context, accentColor: color),
      child: Row(children: [
        Container(
          width: 4, height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppRadius.xl),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(label,
                      style: AppTextStyles.sectionHeader(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(_fmt(amount),
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: color,
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: AppColors.border(context),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
