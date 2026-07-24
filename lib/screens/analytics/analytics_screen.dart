import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/config/constants.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/expense_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  final String roomId;
  const AnalyticsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider(roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(child: Text('No expenses to analyze'));
          }
          final total = expenses.fold<double>(0, (s, e) => s + e.amount);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Total: \u20B9${total.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              Text('By Category',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: _CategoryPieChart(expenses: expenses, total: total),
              ),
              const SizedBox(height: 24),
              Text('Daily Spending',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: _DailyBarChart(expenses: expenses),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final double total;
  const _CategoryPieChart({required this.expenses, required this.total});

  static const _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.amber,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final catTotals = <String, double>{};
    for (final e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final entries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                final pct = (entry.value / total * 100);
                return PieChartSectionData(
                  value: entry.value,
                  color: _colors[idx % _colors.length],
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      color: _colors[idx % _colors.length]),
                  const SizedBox(width: 6),
                  Text('${entry.key} \u20B9${entry.value.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _DailyBarChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final dailyTotals = <int, double>{};
    for (final e in expenses) {
      dailyTotals[e.date.day] = (dailyTotals[e.date.day] ?? 0) + e.amount;
    }
    if (dailyTotals.isEmpty) return const SizedBox();

    final maxY = dailyTotals.values.reduce((a, b) => a > b ? a : b);
    final days = dailyTotals.keys.toList()..sort();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '\u20B9${rod.toY.toStringAsFixed(0)}',
                const TextStyle(color: Colors.white, fontSize: 12),
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
                return Text('${value.toInt()}',
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: days.map((day) {
          return BarChartGroupData(
            x: day,
            barRods: [
              BarChartRodData(
                toY: dailyTotals[day]!,
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
