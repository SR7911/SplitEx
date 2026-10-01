import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';

void showProjectReportsSheet(BuildContext context, String projectId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProjectReportsSheet(projectId: projectId),
  );
}

class _ProjectReportsSheet extends ConsumerStatefulWidget {
  final String projectId;
  const _ProjectReportsSheet({required this.projectId});

  @override
  ConsumerState<_ProjectReportsSheet> createState() => _ProjectReportsSheetState();
}

class _ProjectReportsSheetState extends ConsumerState<_ProjectReportsSheet> {
  int _pieTouched = -1;

  static const _colors = [
    Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF8B5CF6),
    Color(0xFF3B82F6), Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenses = ref.watch(projectExpensesProvider(widget.projectId)).valueOrNull ?? [];
    final project = ref.watch(projectStreamProvider(widget.projectId)).valueOrNull;
    final monthlySpending = ref.watch(projectMonthlySpendingProvider(widget.projectId));
    final categoryBreakdown = ref.watch(projectCategoryBreakdownProvider(widget.projectId));
    final paymentBreakdown = ref.watch(projectPaymentBreakdownProvider(widget.projectId));

    final total = expenses.fold(0.0, (s, e) => s + e.amount);
    final budget = project?.estimatedBudget ?? 0;
    final remaining = budget - total;
    final avg = expenses.isEmpty ? 0.0 : total / expenses.length;
    final catEntries = categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topExpenses = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));

    double lent = 0, borrowed = 0;
    int settledCount = 0, unsettledCount = 0;
    for (final e in expenses.where((e) => e.hasDebt)) {
      if (e.isSettled) { settledCount++; }
      else {
        unsettledCount++;
        if (e.debtType == ProjectDebtType.lent) lent += e.amount;
        else borrowed += e.amount;
      }
    }

    String? burnRateLabel;
    if (expenses.isNotEmpty && remaining > 0) {
      final dates = expenses.map((e) => e.date);
      final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
      final daysSinceStart = DateTime.now().difference(earliest).inDays.clamp(1, 9999);
      final dailyRate = total / daysSinceStart;
      if (dailyRate > 0) {
        final daysLeft = (remaining / dailyRate).round();
        burnRateLabel = '₹${_fmt(dailyRate)}/day · budget lasts ~$daysLeft days';
      }
    }

    return Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        shrinkWrap: true,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cs.primary, cs.primary.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    Text(project?.name ?? 'Project', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (expenses.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.bar_chart_outlined, size: 28, color: cs.onSurface.withOpacity(0.3)),
                    ),
                    const SizedBox(height: 12),
                    Text('No expenses to report', style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
            ),
          ] else ...[

            // Stats banner
            _StatsBanner(isDark: isDark, cs: cs, children: [
              _BannerCell(icon: Icons.receipt_long_rounded, label: 'Total Spent', value: '₹${_fmt(total)}', color: cs.primary),
              _BannerDivider(cs: cs),
              _BannerCell(
                icon: remaining >= 0 ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                label: remaining >= 0 ? 'Remaining' : 'Over Budget',
                value: '₹${_fmt(remaining.abs())}',
                color: remaining >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
              _BannerDivider(cs: cs),
              _BannerCell(icon: Icons.calculate_outlined, label: 'Avg Expense', value: '₹${_fmt(avg)}', color: const Color(0xFF8B5CF6)),
            ]),

            // Burn rate
            if (burnRateLabel != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(burnRateLabel, style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Category breakdown
            if (catEntries.isNotEmpty) ...[
              _SectionHeader(label: 'Spending by Category', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 36,
                                pieTouchData: PieTouchData(
                                  touchCallback: (_, r) => setState(() => _pieTouched = r?.touchedSection?.touchedSectionIndex ?? -1),
                                ),
                                sections: catEntries.asMap().entries.map((e) {
                                  final isTouched = e.key == _pieTouched;
                                  final pct = total > 0 ? e.value.value / total * 100 : 0.0;
                                  return PieChartSectionData(
                                    value: e.value.value,
                                    color: _colors[e.key % _colors.length],
                                    radius: isTouched ? 48 : 38,
                                    title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
                                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  );
                                }).toList(),
                              )),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Spent', style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.45))),
                                  Text('₹${_fmt(total)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurface)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: catEntries.take(5).toList().asMap().entries.map((e) {
                              final color = _colors[e.key % _colors.length];
                              final pct = total > 0 ? (e.value.value / total * 100).toStringAsFixed(0) : '0';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(e.value.key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    Text('$pct%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: cs.outline.withOpacity(0.08)),
                  const SizedBox(height: 12),
                  ...catEntries.asMap().entries.map((e) {
                    final color = _colors[e.key % _colors.length];
                    final pct = total > 0 ? e.value.value / total : 0.0;
                    final isLast = e.key == catEntries.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                      child: Row(
                        children: [
                          Container(width: 3, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.value.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                    Text('₹${_fmt(e.value.value)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 5,
                                    backgroundColor: cs.outline.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              )),
              const SizedBox(height: 20),
            ],

            // Monthly spending
            if (monthlySpending.length > 1) ...[
              _SectionHeader(label: 'Monthly Spending', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: SizedBox(
                height: 150,
                child: _MonthlyBarChart(monthlySpending: monthlySpending, color: cs.primary, cs: cs),
              )),
              const SizedBox(height: 20),
            ],

            // Payment methods
            if (paymentBreakdown.isNotEmpty) ...[
              _SectionHeader(label: 'Payment Methods', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Row(
                children: [
                  SizedBox(
                    width: 90, height: 90,
                    child: PieChart(PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 24,
                      sections: paymentBreakdown.entries.toList().asMap().entries.map((e) {
                        final pct = total > 0 ? e.value.value / total * 100 : 0.0;
                        return PieChartSectionData(
                          value: e.value.value,
                          color: _colors[e.key % _colors.length],
                          radius: 32,
                          title: pct > 10 ? '${pct.toInt()}%' : '',
                          titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    )),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: paymentBreakdown.entries.toList().asMap().entries.map((e) {
                        final color = _colors[e.key % _colors.length];
                        final pct = total > 0 ? (e.value.value / total * 100).toStringAsFixed(0) : '0';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_pmLabel(e.value.key), style: const TextStyle(fontSize: 12))),
                              Text('₹${_fmt(e.value.value)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                              const SizedBox(width: 4),
                              Text('($pct%)', style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 20),
            ],

            // Top expenses
            if (topExpenses.isNotEmpty) ...[
              _SectionHeader(label: 'Top Expenses', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Column(
                children: topExpenses.take(5).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final isLast = i == (topExpenses.length > 5 ? 4 : topExpenses.length - 1);
                  final isLent = e.debtType == ProjectDebtType.lent;
                  final debtColor = isLent ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
                  final rankColors = [const Color(0xFFF59E0B), const Color(0xFF9CA3AF), const Color(0xFFCD7F32)];
                  final rankColor = i < 3 ? rankColors[i] : cs.primary.withOpacity(0.5);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: rankColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: rankColor.withOpacity(0.3))),
                              child: Center(child: Text('#${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: rankColor))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('${e.category} · ${DateFormat('dd MMM yyyy').format(e.date)}', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${_fmt(e.amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
                                if (e.hasDebt)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: (e.isSettled ? Colors.grey : debtColor).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      e.isSettled ? 'Settled' : (isLent ? 'Lent' : 'Borrowed'),
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: e.isSettled ? Colors.grey : debtColor),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) Divider(height: 1, indent: 38, color: cs.outline.withOpacity(0.07)),
                    ],
                  );
                }).toList(),
              )),
              const SizedBox(height: 20),
            ],

            // Debt overview
            if (lent > 0 || borrowed > 0 || settledCount > 0) ...[
              _SectionHeader(label: 'Debt Overview', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Column(
                children: [
                  _StatsBanner(isDark: isDark, cs: cs, children: [
                    _BannerCell(icon: Icons.call_made_rounded, label: 'You Lent', value: '₹${_fmt(lent)}', color: const Color(0xFF22C55E)),
                    _BannerDivider(cs: cs),
                    _BannerCell(icon: Icons.call_received_rounded, label: 'You Borrowed', value: '₹${_fmt(borrowed)}', color: const Color(0xFFEF4444)),
                  ]),
                  if (settledCount > 0 || unsettledCount > 0) ...[
                    const SizedBox(height: 12),
                    _StatsBanner(isDark: isDark, cs: cs, children: [
                      _BannerCell(icon: Icons.check_circle_rounded, label: 'Settled', value: '$settledCount', color: const Color(0xFF22C55E)),
                      _BannerDivider(cs: cs),
                      _BannerCell(icon: Icons.pending_rounded, label: 'Unsettled', value: '$unsettledCount', color: const Color(0xFFEF4444)),
                      _BannerDivider(cs: cs),
                      _BannerCell(
                        icon: Icons.percent_rounded,
                        label: 'Settlement Rate',
                        value: settledCount + unsettledCount > 0 ? '${(settledCount / (settledCount + unsettledCount) * 100).toStringAsFixed(0)}%' : '—',
                        color: const Color(0xFF3B82F6),
                      ),
                    ]),
                  ],
                ],
              )),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Monthly Bar Chart ─────────────────────────────────────────────────────────

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, double> monthlySpending;
  final Color color;
  final ColorScheme cs;
  const _MonthlyBarChart({required this.monthlySpending, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    final entries = monthlySpending.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      maxY: maxVal * 1.25,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: cs.outline.withOpacity(0.08), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, _) {
              final i = value.toInt();
              if (i < 0 || i >= entries.length) return const SizedBox();
              final parts = entries[i].key.split('-');
              final label = DateFormat('MMM').format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
              return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.45))));
            },
          ),
        ),
      ),
      barGroups: List.generate(entries.length, (i) => BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: entries[i].value, color: color, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
      )),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (_, __, rod, ___) => BarTooltipItem('₹${_fmt(rod.toY)}', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    ));
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final Widget child;
  const _ReportCard({required this.isDark, required this.cs, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _SectionHeader({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }
}

class _StatsBanner extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final List<Widget> children;
  const _StatsBanner({required this.isDark, required this.cs, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: IntrinsicHeight(child: Row(children: children)),
    );
  }
}

class _BannerCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _BannerCell({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Row(
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 15, color: color)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.45)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerDivider extends StatelessWidget {
  final ColorScheme cs;
  const _BannerDivider({required this.cs});

  @override
  Widget build(BuildContext context) => VerticalDivider(width: 1, thickness: 1, color: cs.outline.withOpacity(0.1));
}

String _pmLabel(String key) => switch (key) {
  'cash' => 'Cash', 'upi' => 'UPI', 'card' => 'Card', 'bankTransfer' => 'Bank Transfer', _ => key,
};

String _fmt(double v) => NumberFormat('#,##0', 'en_IN').format(v.round());
