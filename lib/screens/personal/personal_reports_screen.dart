import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static const _colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.amber, Colors.pink];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(personalMonthlySummaryProvider(monthKey));
    final spending = ref.watch(personalCategorySpendingProvider(monthKey));
    final txns = ref.watch(personalTransactionsProvider(monthKey)).valueOrNull ?? [];
    final entries = spending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = summary.expenses;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
            // Drag handle
            Center(
              child: Container(
                width: 48, height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            // Header
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Reports • ${_formatMonth(monthKey)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary pills
            Row(
              children: [
                _SummaryPill(label: 'Income', amount: summary.income, color: Colors.green),
                const SizedBox(width: 12),
                _SummaryPill(label: 'Expenses', amount: summary.expenses, color: Colors.red),
              ],
            ),
            const SizedBox(height: 24),

            // Pie chart
            if (entries.isNotEmpty) ...[
              const Text('Category Distribution', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    sections: entries.asMap().entries.map((e) {
                      final pct = totalExpense > 0 ? (e.value.value / totalExpense * 100) : 0;
                      return PieChartSectionData(
                        value: e.value.value,
                        color: _colors[e.key % _colors.length],
                        title: '${pct.toInt()}%',
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        radius: 45,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Category breakdown
              const Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              ...entries.asMap().entries.map((e) {
                final pct = totalExpense > 0 ? (e.value.value / totalExpense * 100).toInt() : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: _colors[e.key % _colors.length], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value.key, style: const TextStyle(fontSize: 13))),
                      Text('₹${e.value.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      SizedBox(width: 40, child: Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Daily spending bar chart
              _DailySpendingChart(monthKey: monthKey, transactions: txns),
            ] else
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No data for this month'))),
          ],
      ),
    );
  }

  String _formatMonth(String key) {
    final parts = key.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMM yyyy').format(dt);
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryPill({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DailySpendingChart extends StatelessWidget {
  final String monthKey;
  final List<PersonalTransactionModel> transactions;
  const _DailySpendingChart({required this.monthKey, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Build daily expense map
    final dailyExpense = <int, double>{};
    for (final t in transactions) {
      if (t.isExpense) {
        dailyExpense[t.date.day] = (dailyExpense[t.date.day] ?? 0) + t.amount;
      }
    }

    final maxVal = dailyExpense.values.isEmpty ? 100.0 : dailyExpense.values.reduce((a, b) => a > b ? a : b);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Spending', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = group.x;
                    final date = DateTime(year, month, day);
                    final dayName = DateFormat('EEE').format(date);
                    return BarTooltipItem(
                      '$dayName, ${day.toString().padLeft(2, '0')}\n₹${rod.toY.toStringAsFixed(0)}',
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
                    getTitlesWidget: (value, meta) {
                      final day = value.toInt();
                      // Show every 5th day + first and last
                      if (day == 1 || day == daysInMonth || day % 5 == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('$day', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
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
                final date = DateTime(year, month, day);
                final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                return BarChartGroupData(
                  x: day,
                  barRods: [
                    BarChartRodData(
                      toY: amount,
                      width: daysInMonth > 28 ? 6 : 8,
                      color: amount > 0
                          ? (isWeekend ? Colors.orange : Theme.of(context).colorScheme.primary)
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: Theme.of(context).colorScheme.primary, label: 'Weekday'),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.orange, label: 'Weekend'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ],
    );
  }
}
