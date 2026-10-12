import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';

void showPersonalReportsSheet(BuildContext context, String monthKey) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PersonalReportsSheet(monthKey: monthKey),
  );
}

class _PersonalReportsSheet extends ConsumerWidget {
  final String monthKey;
  const _PersonalReportsSheet({required this.monthKey});

  static const _colors = [
    Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF8B5CF6),
    Color(0xFF3B82F6), Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = ref.watch(personalMonthlySummaryProvider(monthKey));
    final spending = ref.watch(personalCategorySpendingProvider(monthKey));
    final txns = ref.watch(personalTransactionsProvider(monthKey)).valueOrNull ?? [];
    final entries = spending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = summary.expenses;
    final net = summary.income - summary.expenses;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                    Text(_formatMonth(monthKey), style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats banner
          _StatsBanner(isDark: isDark, cs: cs, children: [
            _BannerCell(icon: Icons.south_rounded, label: 'Income', value: '₹${_fmt(summary.income)}', color: const Color(0xFF22C55E)),
            _BannerDivider(cs: cs),
            _BannerCell(icon: Icons.north_rounded, label: 'Expenses', value: '₹${_fmt(summary.expenses)}', color: const Color(0xFFEF4444)),
            _BannerDivider(cs: cs),
            _BannerCell(
              icon: net >= 0 ? Icons.savings_rounded : Icons.warning_amber_rounded,
              label: net >= 0 ? 'Saved' : 'Deficit',
              value: '₹${_fmt(net.abs())}',
              color: net >= 0 ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
            ),
          ]),
          const SizedBox(height: 24),

          if (entries.isEmpty)
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
                    Text('No data for this month', style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
            )
          else ...[

            // Category donut
            _SectionHeader(label: 'Category Distribution', cs: cs),
            const SizedBox(height: 12),
            _ReportCard(isDark: isDark, cs: cs, child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 44,
                        sections: entries.asMap().entries.map((e) {
                          final pct = totalExpense > 0 ? (e.value.value / totalExpense * 100) : 0.0;
                          return PieChartSectionData(
                            value: e.value.value,
                            color: _colors[e.key % _colors.length],
                            title: pct > 8 ? '${pct.toInt()}%' : '',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            radius: 44,
                          );
                        }).toList(),
                      )),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total', style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.45))),
                          Text('₹${_fmt(totalExpense)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: entries.asMap().entries.map((e) {
                    final color = _colors[e.key % _colors.length];
                    final pct = totalExpense > 0 ? (e.value.value / totalExpense * 100).toInt() : 0;
                    return GestureDetector(
                      onTap: () => context.push('/personal/transactions/category', extra: {'monthKey': monthKey, 'category': e.value.key}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('${e.value.key} $pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 12, color: color),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            )),
            const SizedBox(height: 20),

            // Category breakdown bars
            _SectionHeader(label: 'Spending Breakdown', cs: cs),
            const SizedBox(height: 12),
            _ReportCard(isDark: isDark, cs: cs, child: Column(
              children: entries.asMap().entries.map((e) {
                final color = _colors[e.key % _colors.length];
                final pct = totalExpense > 0 ? e.value.value / totalExpense : 0.0;
                final isLast = e.key == entries.length - 1;
                return GestureDetector(
                  onTap: () => context.push('/personal/transactions/category', extra: {'monthKey': monthKey, 'category': e.value.key}),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Row(
                      children: [
                        Container(width: 3, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.value.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                  Text('₹${_fmt(e.value.value)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                                ],
                              ),
                              const SizedBox(height: 5),
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
                        const SizedBox(width: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 14, color: cs.onSurface.withOpacity(0.3)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )),
            const SizedBox(height: 20),

            // Weekly analysis
            _WeeklyAnalysisSection(monthKey: monthKey, transactions: txns, cs: cs, isDark: isDark),
            const SizedBox(height: 20),

            // Daily spending bar chart
            _DailySpendingChart(monthKey: monthKey, transactions: txns, cs: cs, isDark: isDark),
          ],
        ],
      ),
    );
  }

  String _formatMonth(String key) {
    final parts = key.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMMM yyyy').format(dt);
  }
}

// ── Weekly Analysis Section ──────────────────────────────────────────────────

class _WeeklyAnalysisSection extends StatelessWidget {
  final String monthKey;
  final List<PersonalTransactionModel> transactions;
  final ColorScheme cs;
  final bool isDark;
  const _WeeklyAnalysisSection({required this.monthKey, required this.transactions, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Build weeks: week 1 = days 1-7, week 2 = 8-14, week 3 = 15-21, week 4 = 22-end
    final weekRanges = [
      (1, 7), (8, 14), (15, 21), (22, daysInMonth),
    ];

    final weekData = weekRanges.asMap().entries.map((entry) {
      final i = entry.key;
      final range = entry.value;
      double expense = 0;
      double income = 0;
      int txnCount = 0;
      for (final t in transactions) {
        if (t.date.day >= range.$1 && t.date.day <= range.$2) {
          if (t.isExpense) expense += t.amount;
          else income += t.amount;
          txnCount++;
        }
      }
      return _WeekData(week: i + 1, start: range.$1, end: range.$2, expense: expense, income: income, txnCount: txnCount);
    }).toList();

    final totalExpense = weekData.fold<double>(0, (s, w) => s + w.expense);
    final maxExpense = weekData.map((w) => w.expense).reduce((a, b) => a > b ? a : b);
    final avgWeekly = totalExpense / 4;

    // Find highest and lowest spending weeks
    final sortedByExpense = [...weekData]..sort((a, b) => b.expense.compareTo(a.expense));
    final highestWeek = sortedByExpense.first;
    final lowestWeek = sortedByExpense.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Weekly Analysis', cs: cs),
        const SizedBox(height: 12),
        _ReportCard(
          isDark: isDark, cs: cs,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avg weekly spend chip
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.show_chart_rounded, size: 12, color: cs.primary),
                        const SizedBox(width: 5),
                        Text('Avg ₹${_fmt(avgWeekly)}/week', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (highestWeek.expense > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('W${highestWeek.week} highest', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Week bars
              ...weekData.map((w) {
                final ratio = maxExpense > 0 ? w.expense / maxExpense : 0.0;
                final isHighest = w.week == highestWeek.week && w.expense > 0;
                final isLowest = w.week == lowestWeek.week && w.expense > 0 && lowestWeek.expense < highestWeek.expense;
                final barColor = isHighest
                    ? const Color(0xFFEF4444)
                    : isLowest
                        ? const Color(0xFF22C55E)
                        : cs.primary;
                final aboveAvg = w.expense > avgWeekly && avgWeekly > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              'W${w.week} (${w.start}-${w.end})',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.55)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 10,
                                backgroundColor: cs.outline.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: Text(
                              '₹${_fmt(w.expense)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: barColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (aboveAvg)
                            Icon(Icons.arrow_upward_rounded, size: 12, color: const Color(0xFFEF4444))
                          else if (w.expense > 0)
                            Icon(Icons.arrow_downward_rounded, size: 12, color: const Color(0xFF22C55E))
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                      if (w.txnCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 60, top: 3),
                          child: Text(
                            '${w.txnCount} txn${w.txnCount > 1 ? 's' : ''} • income ₹${_fmt(w.income)}',
                            style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4)),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              // Insight row
              if (highestWeek.expense > 0 && lowestWeek.expense < highestWeek.expense) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 14, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Week ${highestWeek.week} spent ${((highestWeek.expense / (lowestWeek.expense > 0 ? lowestWeek.expense : 1) - 1) * 100).toInt()}% more than Week ${lowestWeek.week}',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.55)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekData {
  final int week, start, end, txnCount;
  final double expense, income;
  const _WeekData({required this.week, required this.start, required this.end, required this.expense, required this.income, required this.txnCount});
}

// ── Daily Spending Chart ──────────────────────────────────────────────────────

class _DailySpendingChart extends StatelessWidget {
  final String monthKey;
  final List<PersonalTransactionModel> transactions;
  final ColorScheme cs;
  final bool isDark;
  const _DailySpendingChart({required this.monthKey, required this.transactions, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final dailyExpense = <int, double>{};
    for (final t in transactions) {
      if (t.isExpense) dailyExpense[t.date.day] = (dailyExpense[t.date.day] ?? 0) + t.amount;
    }

    final maxVal = dailyExpense.values.isEmpty ? 100.0 : dailyExpense.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Daily Spending', cs: cs),
        const SizedBox(height: 12),
        _ReportCard(
          isDark: isDark, cs: cs,
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, _, rod, __) {
                        final date = DateTime(year, month, group.x);
                        return BarTooltipItem(
                          '${DateFormat('EEE d').format(date)}\n₹${rod.toY.toStringAsFixed(0)}',
                          TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w600),
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
                        getTitlesWidget: (value, _) {
                          final day = value.toInt();
                          if (day == 1 || day == daysInMonth || day % 7 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('$day', style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.45))),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: List.generate(daysInMonth, (i) {
                    final day = i + 1;
                    final amount = dailyExpense[day] ?? 0;
                    final isWeekend = DateTime(year, month, day).weekday >= 6;
                    return BarChartGroupData(
                      x: day,
                      barRods: [
                        BarChartRodData(
                          toY: amount,
                          width: daysInMonth > 28 ? 5 : 7,
                          color: amount > 0
                              ? (isWeekend ? const Color(0xFFF59E0B) : cs.primary)
                              : cs.outline.withOpacity(0.12),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }),
                )),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: cs.primary, label: 'Weekday', cs: cs),
                  const SizedBox(width: 16),
                  _LegendDot(color: const Color(0xFFF59E0B), label: 'Weekend', cs: cs),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: color),
            ),
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
  Widget build(BuildContext context) {
    return VerticalDivider(width: 1, thickness: 1, color: cs.outline.withOpacity(0.1));
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final ColorScheme cs;
  const _LegendDot({required this.color, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
      ],
    );
  }
}

String _fmt(double v) => NumberFormat('#,##0', 'en_IN').format(v.round());
