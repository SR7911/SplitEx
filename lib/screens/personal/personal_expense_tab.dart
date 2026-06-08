import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';
import 'package:split_ex/screens/personal/personal_reports_screen.dart';
import 'package:split_ex/screens/personal/view_personal_transaction_sheet.dart';

class PersonalExpenseTab extends ConsumerStatefulWidget {
  const PersonalExpenseTab({super.key});

  @override
  ConsumerState<PersonalExpenseTab> createState() => _PersonalExpenseTabState();
}

class _PersonalExpenseTabState extends ConsumerState<PersonalExpenseTab> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  bool get _isCurrentMonth =>
      _selectedMonth.year == DateTime.now().year &&
      _selectedMonth.month == DateTime.now().month;

  void _prevMonth() => setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      });

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(personalMonthlySummaryProvider(_monthKey));
    final categorySpending = ref.watch(personalCategorySpendingProvider(_monthKey));
    final budgets = ref.watch(personalBudgetsProvider(_monthKey)).valueOrNull ?? [];
    final recurring = ref.watch(personalRecurringProvider).valueOrNull ?? [];
    final txns = ref.watch(personalTransactionsProvider(_monthKey)).valueOrNull ?? [];
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userName = profile?.name ?? 'User';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
          // ─── Greeting ───
          _GreetingHeader(userName: userName, selectedMonth: _selectedMonth),
          const SizedBox(height: 20),

          // ─── P1: Financial Status Card ───
          _FinancialStatusCard(
            summary: summary,
            selectedMonth: _selectedMonth,
            isCurrentMonth: _isCurrentMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          const SizedBox(height: 20),

          // ─── P1.5: Income & Expense Pills ───
          _IncomeExpensePills(summary: summary, monthLabel: DateFormat('MMM').format(_selectedMonth)),
          const SizedBox(height: 20),

          // ─── Budget Usage Card (separate) ───
          _BudgetUsageCard(summary: summary),
          const SizedBox(height: 20),

          // ─── P2: Category Budgets ───
          if (categorySpending.isNotEmpty)
            _CategoryBudgetsSection(spending: categorySpending, budgets: budgets),
          if (categorySpending.isNotEmpty) const SizedBox(height: 8),

          _QuickActions(monthKey: _monthKey),
          const SizedBox(height: 12),

          // ─── Utility shortcuts (easily accessible) ───
          _UtilitiesRow(monthKey: _monthKey),
          const SizedBox(height: 20),

          // ─── P3: Spending Breakdown Pie ───
          if (categorySpending.isNotEmpty)
            _SpendingPieChart(spending: categorySpending),
          if (categorySpending.isNotEmpty) const SizedBox(height: 20),

          // ─── P4: Recent Transactions ───
          _RecentTransactionsSection(transactions: txns.take(5).toList(), monthKey: _monthKey),
          const SizedBox(height: 20),

          // ─── P5: Recurring preview ───
          if (recurring.isNotEmpty) _RecurringSection(items: recurring),
          const SizedBox(height: 40),
        ],
      ),
      Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton(
          onPressed: () => showAddPersonalTransactionSheet(context),
          child: const Icon(Icons.add),
        ),
      ),
    ],
  );
  }
}

// ══════════════════════════════════════
// Sub-widgets (matching Room tab style)
// ══════════════════════════════════════

class _GreetingHeader extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;
  const _GreetingHeader({required this.userName, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final isCurrent = selectedMonth.year == DateTime.now().year && selectedMonth.month == DateTime.now().month;
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, $userName 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(monthStr, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600)),
            if (isCurrent)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              ),
          ],
        ),
      ],
    );
  }
}

class _FinancialStatusCard extends StatelessWidget {
  final dynamic summary;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _FinancialStatusCard({required this.summary, required this.selectedMonth, required this.isCurrentMonth, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remaining as double;
    final isPositive = remaining >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = LinearGradient(
      colors: isPositive
          ? (isDark ? [Colors.green.shade900.withOpacity(0.3), Colors.green.shade800.withOpacity(0.3)] : [Colors.green.shade50, Colors.green.shade100])
          : (isDark ? [Colors.red.shade900.withOpacity(0.3), Colors.red.shade800.withOpacity(0.3)] : [Colors.red.shade50, Colors.red.shade100]),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: bgGradient),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: onPrev,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface, foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(selectedMonth),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      IconButton(
                        onPressed: isCurrentMonth ? null : onNext,
                        icon: const Icon(Icons.chevron_right, size: 20),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface, foregroundColor: isCurrentMonth ? Colors.grey : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Remaining balance
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPositive ? 'Remaining' : 'Overspent',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isPositive ? Icons.savings_rounded : Icons.warning_rounded, size: 32, color: color),
                            const SizedBox(width: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: remaining.abs()),
                              duration: const Duration(milliseconds: 600),
                              builder: (context, value, _) => Text(
                                '₹${value.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Decorative watermark
          Positioned(
            left: -25,
            bottom: 10,
            child: IgnorePointer(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1)),
                child: Icon(Icons.account_balance_wallet_rounded, size: 40, color: color.withOpacity(0.15)),
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            right: -10,
            child: IgnorePointer(
              child: Icon(Icons.currency_rupee_rounded, size: 60, color: color.withOpacity(0.1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpensePills extends StatelessWidget {
  final dynamic summary;
  final String monthLabel;
  const _IncomeExpensePills({required this.summary, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        // Income pill
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.arrow_downward_rounded, size: 28, color: isDark ? Colors.green.shade300 : Colors.green.shade700),
                const SizedBox(height: 2),
                Text(
                  '₹${(summary.income as double).toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade200 : Colors.green.shade800),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Income', style: TextStyle(fontSize: 12, color: isDark ? Colors.green.shade300 : Colors.green.shade600)),
                    Text(' ($monthLabel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.green.shade400 : Colors.green.shade400)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Expense pill
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(Icons.arrow_upward_rounded, size: 28, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                const SizedBox(height: 2),
                Text(
                  '₹${(summary.expenses as double).toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade200 : Colors.red.shade800),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Expenses', style: TextStyle(fontSize: 12, color: isDark ? Colors.red.shade300 : Colors.red.shade600)),
                    Text(' ($monthLabel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.red.shade400 : Colors.red.shade400)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBudgetsSection extends StatelessWidget {
  final Map<String, double> spending;
  final List<CategoryBudget> budgets;
  const _CategoryBudgetsSection({required this.spending, required this.budgets});

  @override
  Widget build(BuildContext context) {
    final budgetMap = <String, double>{};
    for (final b in budgets) {
      budgetMap[b.category] = b.budget;
    }

    final allCategories = {...spending.keys, ...budgetMap.keys}.toList();
    allCategories.sort((a, b) => (spending[b] ?? 0).compareTo(spending[a] ?? 0));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Category Budgets', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 14),
            ...allCategories.take(5).map((cat) {
              final spent = spending[cat] ?? 0;
              final budget = budgetMap[cat] ?? 0;
              final ratio = budget > 0 ? spent / budget : 0.0;
              final percent = (ratio * 100).toInt();
              final color = percent <= 70 ? Colors.green : percent <= 100 ? Colors.orange : Colors.red;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Text(
                          budget > 0 ? '₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}' : '₹${spent.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                        ),
                      ],
                    ),
                    if (budget > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.5),
                          minHeight: 5,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          color: color,
                        ),
                      ),
                      if (percent > 100)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Over budget!', style: TextStyle(fontSize: 10, color: Colors.red.shade400, fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BudgetUsageCard extends StatelessWidget {
  final dynamic summary;
  const _BudgetUsageCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final usage = summary.budgetUsage as double;
    final percent = (usage * 100).clamp(0, 999).toInt();
    final color = percent <= 70 ? Colors.green : percent <= 100 ? Colors.orange : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expense vs Income', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              Text('$percent%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usage.clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              color: color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            percent <= 70
                ? 'Healthy spending — well within budget'
                : percent <= 100
                    ? 'Approaching your income limit'
                    : 'Overspending — expenses exceed income',
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final String monthKey;
  const _QuickActions({required this.monthKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => showAddPersonalTransactionSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/personal/budgets', extra: monthKey),
            icon: const Icon(Icons.tune),
            label: const Text('Budgets'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          ),
        ),
      ],
    );
  }
}

class _SpendingPieChart extends StatelessWidget {
  final Map<String, double> spending;
  const _SpendingPieChart({required this.spending});

  static const _colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.amber, Colors.pink];

  @override
  Widget build(BuildContext context) {
    final entries = spending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.donut_large_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Spending Breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                      sections: entries.asMap().entries.map((e) => PieChartSectionData(
                        value: e.value.value,
                        color: _colors[e.key % _colors.length],
                        title: '',
                        radius: 48,
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: entries.take(6).map((e) {
                      final idx = entries.indexOf(e);
                      final pct = (e.value / total * 100).toInt();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _colors[idx % _colors.length].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: _colors[idx % _colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              '${e.key} $pct%',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _colors[idx % _colors.length]),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  final List<PersonalTransactionModel> transactions;
  final String monthKey;
  const _RecentTransactionsSection({required this.transactions, required this.monthKey});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/personal/transactions', extra: DateFormat('yyyy-MM').format(DateTime.now())),
                  child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text('No transactions yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ...transactions.asMap().entries.map((entry) {
                final txn = entry.value;
                final isLast = entry.key == transactions.length - 1;
                final isIncome = txn.isIncome;
                final color = isIncome ? Colors.green : Colors.red;
                final sign = isIncome ? '+' : '-';

                return Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => showPersonalTransactionDetail(context, txn),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: color),
                      ),
                      title: Text(txn.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${txn.category} • ${DateFormat('dd MMM').format(txn.date)}',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      trailing: Text('$sign₹${txn.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RecurringSection extends StatelessWidget {
  final List<RecurringTransaction> items;
  const _RecurringSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Recurring', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/personal/recurring'),
                  child: Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.take(3).map((r) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: r.active
                            ? (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        r.active ? Icons.autorenew_rounded : Icons.pause_circle_outline,
                        size: 18,
                        color: r.active ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('${r.frequency.name} • Day ${r.dayOfMonth}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ),
                    Text('₹${r.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UtilitiesRow extends StatelessWidget {
  final String monthKey;
  const _UtilitiesRow({required this.monthKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _UtilityCard(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            color: Colors.purple,
            onTap: () => showPersonalReportsSheet(context, monthKey),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _UtilityCard(
            icon: Icons.list_alt_rounded,
            label: 'All Transactions',
            color: Colors.blue,
            onTap: () => context.push('/personal/transactions', extra: monthKey),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _UtilityCard(
            icon: Icons.repeat_rounded,
            label: 'Recurring',
            color: Colors.teal,
            onTap: () => context.push('/personal/recurring'),
          ),
        ),
      ],
    );
  }
}

class _UtilityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _UtilityCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
