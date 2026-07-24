import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

void showGroupReportsSheet(BuildContext context, String groupId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupReportsSheet(groupId: groupId),
  );
}

class _GroupReportsSheet extends ConsumerStatefulWidget {
  final String groupId;
  const _GroupReportsSheet({required this.groupId});

  @override
  ConsumerState<_GroupReportsSheet> createState() => _GroupReportsSheetState();
}

class _GroupReportsSheetState extends ConsumerState<_GroupReportsSheet> {
  int _pieTouched = -1;

  static const _colors = [
    Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFFEF5350),
    Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFAB47BC),
    Color(0xFF29B6F6), Color(0xFFFFCA28),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expenses = ref.watch(groupExpensesProvider(widget.groupId)).valueOrNull ?? [];
    final group = ref.watch(groupStreamProvider(widget.groupId)).valueOrNull;
    final uid = ref.watch(currentUserIdProvider);
    final monthlySpending = ref.watch(groupMonthlySpendingProvider(widget.groupId));
    final categoryBreakdown = ref.watch(groupCategoryBreakdownProvider(widget.groupId));
    final splitTypeBreakdown = ref.watch(groupSplitTypeBreakdownProvider(widget.groupId));
    final netBalances = ref.watch(groupNetBalancesProvider(widget.groupId));
    final membersAsync = ref.watch(roomMembersProvider(group?.memberIds ?? []));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }

    final total = expenses.fold(0.0, (s, e) => s + e.amount);
    final mySpend = expenses.where((e) => e.paidBy == uid).fold(0.0, (s, e) => s + e.amount);
    final avg = expenses.isEmpty ? 0.0 : total / expenses.length;

    final catEntries = categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Per-member paid amounts
    final spendMap = <String, double>{};
    for (final e in expenses) {
      spendMap[e.paidBy] = (spendMap[e.paidBy] ?? 0) + e.amount;
    }
    final membersSorted = spendMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final topExpenses = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));

    // Balance sorted: most owed first
    final balanceSorted = netBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        shrinkWrap: true,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Header
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${group?.name ?? 'Group'} · Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (expenses.isEmpty) ...[
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart_outlined, size: 48, color: cs.onSurface.withOpacity(0.15)),
                  const SizedBox(height: 12),
                  Text('No expenses to report',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ] else ...[

            // ── Summary chips ──────────────────────────────────────────────
            Row(
              children: [
                _Chip(label: 'Total Spent', value: '₹${_fmt(total)}', color: cs.primary),
                const SizedBox(width: 8),
                _Chip(label: 'You Paid', value: '₹${_fmt(mySpend)}', color: Colors.purple),
                const SizedBox(width: 8),
                _Chip(label: 'Avg Expense', value: '₹${_fmt(avg)}', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 20),

            // ── Category Breakdown ─────────────────────────────────────────
            if (catEntries.isNotEmpty) ...[
              _SectionLabel('Spending by Category'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 130,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: PieChart(PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 30,
                                pieTouchData: PieTouchData(
                                  touchCallback: (_, r) => setState(() =>
                                      _pieTouched = r?.touchedSection?.touchedSectionIndex ?? -1),
                                ),
                                sections: catEntries.asMap().entries.map((e) {
                                  final isTouched = e.key == _pieTouched;
                                  final pct = total > 0 ? e.value.value / total * 100 : 0.0;
                                  return PieChartSectionData(
                                    value: e.value.value,
                                    color: _colors[e.key % _colors.length],
                                    radius: isTouched ? 50 : 40,
                                    title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
                                    titleStyle: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  );
                                }).toList(),
                              )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: catEntries.take(5).toList().asMap().entries.map((e) {
                                  final pct = total > 0
                                      ? (e.value.value / total * 100).toStringAsFixed(0)
                                      : '0';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8, height: 8,
                                          decoration: BoxDecoration(
                                              color: _colors[e.key % _colors.length],
                                              shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(e.value.key,
                                              style: const TextStyle(fontSize: 11),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        Text('$pct%',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _colors[e.key % _colors.length])),
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
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Ranked bars
                      ...catEntries.map((e) {
                        final pct = total > 0 ? e.value / total : 0.0;
                        final idx = catEntries.indexOf(e);
                        final color = _colors[idx % _colors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key, style: const TextStyle(fontSize: 12)),
                                  Text(
                                    '₹${_fmt(e.value)} · ${(pct * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w600, color: color),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 5,
                                  backgroundColor: color.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation(color),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Monthly Spending ───────────────────────────────────────────
            if (monthlySpending.length > 1) ...[
              _SectionLabel('Monthly Spending'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
                  child: SizedBox(
                    height: 150,
                    child: _MonthlyBarChart(monthlySpending: monthlySpending, color: cs.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Who Paid ───────────────────────────────────────────────────
            if (membersSorted.isNotEmpty) ...[
              _SectionLabel('Who Paid Most'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: membersSorted.map((entry) {
                      final isMe = entry.key == uid;
                      final name = nameMap[entry.key] ?? entry.key.substring(0, 6);
                      final pct = membersSorted.first.value > 0
                          ? entry.value / membersSorted.first.value
                          : 0.0;
                      final share = total > 0 ? entry.value / total * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: cs.primary.withOpacity(isMe ? 0.2 : 0.08),
                              child: Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                isMe ? 'You' : name,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: cs.primary.withOpacity(0.08),
                                  valueColor: AlwaysStoppedAnimation(
                                      isMe ? cs.primary : cs.primary.withOpacity(0.45)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('₹${_fmt(entry.value)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            Text('${share.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    fontSize: 10, color: cs.onSurface.withOpacity(0.45))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Member Balances ────────────────────────────────────────────
            if (balanceSorted.isNotEmpty) ...[
              _SectionLabel('Member Balances'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: balanceSorted.map((entry) {
                      final isMe = entry.key == uid;
                      final name = nameMap[entry.key] ?? entry.key.substring(0, 6);
                      final isOwed = entry.value > 0.01;
                      final owes = entry.value < -0.01;
                      final color = isOwed
                          ? const Color(0xFF10B981)
                          : owes
                              ? const Color(0xFFEF4444)
                              : cs.onSurface.withOpacity(0.4);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: color.withOpacity(0.12),
                              child: Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isMe ? 'You' : name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                                    color: cs.onSurface),
                              ),
                            ),
                            Text(
                              isOwed
                                  ? 'gets back ₹${entry.value.toStringAsFixed(0)}'
                                  : owes
                                      ? 'owes ₹${entry.value.abs().toStringAsFixed(0)}'
                                      : 'settled',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Split Type Breakdown ───────────────────────────────────────
            if (splitTypeBreakdown.isNotEmpty) ...[
              _SectionLabel('Split Types Used'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: splitTypeBreakdown.entries.map((e) {
                      final total = splitTypeBreakdown.values.fold(0, (s, v) => s + v);
                      final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
                      final idx = splitTypeBreakdown.keys.toList().indexOf(e.key);
                      final color = _colors[idx % _colors.length];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.2)),
                        ),
                        child: Text(
                          '${_splitLabel(e.key)} · ${e.value} (${pct}%)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: color),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Top Expenses ───────────────────────────────────────────────
            if (topExpenses.isNotEmpty) ...[
              _SectionLabel('Top Expenses'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: topExpenses.take(5).toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final isLast = i == (topExpenses.length > 5 ? 4 : topExpenses.length - 1);
                    final paidByName = nameMap[e.paidBy] ?? e.paidBy.substring(0, 6);
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('#${i + 1}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: cs.primary)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.title,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                      '${e.category} · ${DateFormat('dd MMM').format(e.date)} · paid by ${e.paidBy == uid ? 'You' : paidByName}',
                                      style: TextStyle(
                                          fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                                    ),
                                  ],
                                ),
                              ),
                              Text('₹${_fmt(e.amount)}',
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                              height: 1,
                              indent: 48,
                              color: cs.onSurface.withOpacity(0.08)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Monthly Bar Chart ────────────────────────────────────────────────────────

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, double> monthlySpending;
  final Color color;
  const _MonthlyBarChart({required this.monthlySpending, required this.color});

  @override
  Widget build(BuildContext context) {
    final entries = monthlySpending.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxVal * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.withOpacity(0.12), strokeWidth: 1),
        ),
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
                final label = DateFormat('MMM').format(
                    DateTime(int.parse(parts[0]), int.parse(parts[1])));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          entries.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                color: color,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              '₹${_fmt(rod.toY)}',
              const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

String _splitLabel(String key) => switch (key) {
      'equal' => 'Equal',
      'percentage' => 'Percentage',
      'custom' => 'Custom',
      'shares' => 'Shares',
      'selected' => 'Selected',
      _ => key,
    };

String _fmt(double v) => NumberFormat('#,##0', 'en_IN').format(v.round());
