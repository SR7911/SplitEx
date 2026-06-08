import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
