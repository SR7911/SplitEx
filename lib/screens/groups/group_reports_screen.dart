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
    Color(0xFF6366F1), Color(0xFF22C55E), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFF8B5CF6),
    Color(0xFF3B82F6), Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final spendMap = <String, double>{};
    for (final e in expenses) spendMap[e.paidBy] = (spendMap[e.paidBy] ?? 0) + e.amount;
    final membersSorted = spendMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topExpenses = [...expenses]..sort((a, b) => b.amount.compareTo(a.amount));
    final balanceSorted = netBalances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

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
                    Text(group?.name ?? 'Group', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)), overflow: TextOverflow.ellipsis),
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
              _BannerCell(icon: Icons.person_rounded, label: 'You Paid', value: '₹${_fmt(mySpend)}', color: const Color(0xFF8B5CF6)),
              _BannerDivider(cs: cs),
              _BannerCell(icon: Icons.calculate_outlined, label: 'Avg Expense', value: '₹${_fmt(avg)}', color: const Color(0xFFF59E0B)),
            ]),
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
                                  Text('Total', style: TextStyle(fontSize: 9, color: cs.onSurface.withOpacity(0.45))),
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

            // Who paid most
            if (membersSorted.isNotEmpty) ...[
              _SectionHeader(label: 'Who Paid Most', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Column(
                children: membersSorted.asMap().entries.map((entry) {
                  final e = entry.value;
                  final isMe = e.key == uid;
                  final name = nameMap[e.key] ?? e.key.substring(0, 6);
                  final pct = membersSorted.first.value > 0 ? e.value / membersSorted.first.value : 0.0;
                  final share = total > 0 ? e.value / total * 100 : 0.0;
                  final isLast = entry.key == membersSorted.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(isMe ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: isMe ? Border.all(color: cs.primary.withOpacity(0.4)) : null,
                          ),
                          child: Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary))),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 60,
                          child: Text(isMe ? 'You' : name, style: TextStyle(fontSize: 12, fontWeight: isMe ? FontWeight.w700 : FontWeight.w500, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: cs.outline.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(isMe ? cs.primary : cs.primary.withOpacity(0.4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('₹${_fmt(e.value)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        Text('${share.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
                      ],
                    ),
                  );
                }).toList(),
              )),
              const SizedBox(height: 20),
            ],

            // Member balances
            if (balanceSorted.isNotEmpty) ...[
              _SectionHeader(label: 'Member Balances', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Column(
                children: balanceSorted.asMap().entries.map((entry) {
                  final e = entry.value;
                  final isMe = e.key == uid;
                  final name = nameMap[e.key] ?? e.key.substring(0, 6);
                  final isOwed = e.value > 0.01;
                  final owes = e.value < -0.01;
                  final color = isOwed ? const Color(0xFF22C55E) : owes ? const Color(0xFFEF4444) : cs.onSurface.withOpacity(0.4);
                  final isLast = entry.key == balanceSorted.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withOpacity(0.2)),
                          ),
                          child: Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(isMe ? 'You' : name, style: TextStyle(fontSize: 13, fontWeight: isMe ? FontWeight.w700 : FontWeight.w500, color: cs.onSurface))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
                          child: Text(
                            isOwed ? 'gets ₹${e.value.toStringAsFixed(0)}' : owes ? 'owes ₹${e.value.abs().toStringAsFixed(0)}' : 'settled',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )),
              const SizedBox(height: 20),
            ],

            // Split types
            if (splitTypeBreakdown.isNotEmpty) ...[
              _SectionHeader(label: 'Split Types Used', cs: cs),
              const SizedBox(height: 12),
              _ReportCard(isDark: isDark, cs: cs, child: Wrap(
                spacing: 8, runSpacing: 8,
                children: splitTypeBreakdown.entries.toList().asMap().entries.map((entry) {
                  final e = entry.value;
                  final totalCount = splitTypeBreakdown.values.fold(0, (s, v) => s + v);
                  final pct = totalCount > 0 ? (e.value / totalCount * 100).toStringAsFixed(0) : '0';
                  final color = _colors[entry.key % _colors.length];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text('${_splitLabel(e.key)} · ${e.value} ($pct%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                  );
                }).toList(),
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
                  final paidByName = nameMap[e.paidBy] ?? e.paidBy.substring(0, 6);
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
                                  Text('${e.category} · ${DateFormat('dd MMM').format(e.date)} · ${e.paidBy == uid ? 'You' : paidByName}',
                                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
                                ],
                              ),
                            ),
                            Text('₹${_fmt(e.amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
                          ],
                        ),
                      ),
                      if (!isLast) Divider(height: 1, indent: 38, color: cs.outline.withOpacity(0.07)),
                    ],
                  );
                }).toList(),
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

String _splitLabel(String key) => switch (key) {
  'equal' => 'Equal', 'percentage' => 'Percentage', 'custom' => 'Custom',
  'shares' => 'Shares', 'selected' => 'Selected', _ => key,
};

String _fmt(double v) => NumberFormat('#,##0', 'en_IN').format(v.round());
