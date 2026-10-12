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
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

// -- Shared accent colors --------------------------------------------------
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);

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
    final summary          = ref.watch(personalMonthlySummaryProvider(_monthKey));
    final categorySpending = ref.watch(personalCategorySpendingProvider(_monthKey));
    final budgets          = ref.watch(personalBudgetsProvider(_monthKey)).valueOrNull ?? [];
    final recurring        = ref.watch(personalRecurringProvider).valueOrNull ?? [];
    final txns             = ref.watch(personalTransactionsProvider(_monthKey)).valueOrNull ?? [];
    final profile          = ref.watch(userProfileProvider).valueOrNull;
    final userName         = profile?.name ?? 'User';

    final bodySliver = [
      if (categorySpending.isNotEmpty) ...[
        _CategoryBudgetsSection(spending: categorySpending, budgets: budgets),
        const SizedBox(height: 20),
        _SpendingPieChart(spending: categorySpending),
        const SizedBox(height: 20),
      ],
      _RecentTransactionsSection(transactions: txns.take(5).toList(), monthKey: _monthKey),
      const SizedBox(height: 20),
      const _DebtsSummarySection(),
      const SizedBox(height: 20),
      const _LoanSummarySection(),
      const SizedBox(height: 20),
      if (recurring.isNotEmpty) _RecurringSection(items: recurring),
      const SizedBox(height: 80),
    ];

    Widget body;
    body = Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            _GreetingHeader(userName: userName),
            const SizedBox(height: 20),
            _FinancialStatusCard(
              summary: summary, selectedMonth: _selectedMonth,
              isCurrentMonth: _isCurrentMonth, onPrev: _prevMonth, onNext: _nextMonth,
            ),
            const SizedBox(height: 16),
            _IncomeExpensePills(summary: summary),
            const SizedBox(height: 16),
            _BudgetUsageCard(summary: summary),
            const SizedBox(height: 20),
            _QuickActionsRow(monthKey: _monthKey),
            const SizedBox(height: 20),
            _WeeklyExpenseSummaryCard(monthKey: _monthKey),
            const SizedBox(height: 20),
            ...bodySliver,
          ],
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            onPressed: () => showAddPersonalTransactionSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );

    return body;
  }
}

// -- Public builder functions used by external layout widgets -------------

Widget incomeExpensePills(BuildContext context, dynamic summary) =>
    _IncomeExpensePills(summary: summary);

Widget budgetUsageCard(BuildContext context, dynamic summary) =>
    _BudgetUsageCard(summary: summary);

Widget quickActionsRow(BuildContext context, String monthKey) =>
    _QuickActionsRow(monthKey: monthKey);

// -- Helpers ---------------------------------------------------------------

Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) {
  if (trailing == null) return AppSectionHeader(title: title, actionLabel: null, onAction: null);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      trailing,
    ],
  );
}

Widget _viewAllChip(BuildContext context, VoidCallback onTap) {
  final cs = Theme.of(context).colorScheme;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
    ),
  );
}

BoxDecoration _cardDecoration(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? cs.surfaceContainerHigh : cs.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

// -- _GreetingHeader -------------------------------------------------------

class _GreetingHeader extends StatelessWidget {
  final String userName;
  const _GreetingHeader({required this.userName});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting()}, $userName ??',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Here\'s your financial overview',
          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

// -- _FinancialStatusCard --------------------------------------------------

class _FinancialStatusCard extends StatelessWidget {
  final dynamic summary;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _FinancialStatusCard({
    required this.summary,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final remaining   = summary.remaining as double;
    final income      = summary.income as double;
    final expenses    = summary.expenses as double;
    final isPositive  = remaining >= 0;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final spendRatio  = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final savingsRate = income > 0 ? ((remaining / income) * 100).clamp(-999.0, 100.0) : 0.0;

    // Gradient palette: green-teal when healthy, red-orange when overspent
    final gradientColors = isPositive
        ? (isDark
            ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
            : [const Color(0xFF059669), const Color(0xFF0D9488)])
        : (isDark
            ? [const Color(0xFF7F1D1D), const Color(0xFF831843)]
            : [const Color(0xFFDC2626), const Color(0xFFDB2777)]);

    final onCard = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.65);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative blobs
            Positioned(
              top: -40, right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30, left: -30,
              child: IgnorePointer(
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Top row: month nav --
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavChip(onTap: onPrev, icon: Icons.chevron_left, onCard: onCard),
                      Column(
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(selectedMonth),
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: onCard),
                          ),
                          if (isCurrentMonth)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Current Month',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: onCard, letterSpacing: 0.4),
                              ),
                            ),
                        ],
                      ),
                      _NavChip(onTap: isCurrentMonth ? null : onNext, icon: Icons.chevron_right, onCard: onCard),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // -- Balance label --
                  Text(
                    isPositive ? 'Remaining Balance' : 'Overspent By',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onCardMuted, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 6),

                  // -- Big balance number --
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: remaining.abs()),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '₹${_fmt(value)}',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: onCard,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // -- Income / Expense inline chips --
                  Row(
                    children: [
                      _HeroChip(
                        icon: Icons.south_rounded,
                        label: 'Income',
                        value: '₹${_fmt(income)}',
                        onCard: onCard,
                        onCardMuted: onCardMuted,
                      ),
                      const SizedBox(width: 10),
                      _HeroChip(
                        icon: Icons.north_rounded,
                        label: 'Spent',
                        value: '₹${_fmt(expenses)}',
                        onCard: onCard,
                        onCardMuted: onCardMuted,
                      ),
                      const Spacer(),
                      // Savings badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.savings_rounded : Icons.warning_amber_rounded,
                              size: 16, color: onCard,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              income > 0 ? '${savingsRate.toInt()}%' : '—',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard),
                            ),
                            Text('saved', style: TextStyle(fontSize: 9, color: onCardMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // -- Spend progress bar --
                  if (income > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(spendRatio * 100).toInt()}% of income spent',
                          style: TextStyle(fontSize: 10, color: onCardMuted),
                        ),
                        Text(
                          '₹${_fmt(remaining.abs())} ${isPositive ? 'left' : 'over'}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: onCard),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: spendRatio,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.9)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0);




}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color onCard;
  final Color onCardMuted;
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCard,
    required this.onCardMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: onCardMuted),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: onCardMuted, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onCard)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color onCard;
  const _NavChip({required this.onTap, required this.icon, required this.onCard});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: onCard.withValues(alpha: enabled ? 0.9 : 0.3)),
      ),
    );
  }
}

// -- _IncomeExpensePills ---------------------------------------------------

class _IncomeExpensePills extends StatelessWidget {
  final dynamic summary;
  const _IncomeExpensePills({required this.summary});

  String _fmt(double v) => v.toStringAsFixed(0);





  @override
  Widget build(BuildContext context) {
    final income   = summary.income as double;
    final expenses = summary.expenses as double;
    final net      = income - expenses;
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(child: _MiniStatCard(label: 'Income',   value: income,        icon: Icons.south_rounded,          color: _kGreen,                    isDark: isDark, cs: cs, fmt: _fmt)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStatCard(label: 'Expenses', value: expenses,      icon: Icons.north_rounded,          color: _kRed,                      isDark: isDark, cs: cs, fmt: _fmt)),
        const SizedBox(width: 10),
        Expanded(child: _MiniStatCard(label: net >= 0 ? 'Saved' : 'Deficit', value: net.abs(), icon: net >= 0 ? Icons.savings_rounded : Icons.trending_down_rounded, color: net >= 0 ? _kTeal : _kAmber, isDark: isDark, cs: cs, fmt: _fmt)),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  final String Function(double) fmt;
  const _MiniStatCard({
    required this.label, required this.value, required this.icon,
    required this.color, required this.isDark, required this.cs, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            '₹${fmt(value)}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// -- _BudgetUsageCard ------------------------------------------------------

class _BudgetUsageCard extends StatelessWidget {
  final dynamic summary;
  const _BudgetUsageCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final income   = summary.income as double;
    final expenses = summary.expenses as double;
    final saved    = (income - expenses).clamp(0.0, double.infinity);
    final usage    = summary.budgetUsage as double;
    final percent  = (usage * 100).clamp(0, 999).toInt();
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final statusColor = percent <= 70 ? _kGreen : percent <= 100 ? _kAmber : _kRed;
    final statusLabel = percent <= 70 ? 'On Track' : percent <= 100 ? 'Caution' : 'Over Budget';

    // segment ratios
    final spentRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final savedRatio = income > 0 ? (saved / income).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          _sectionHeader(
            context, 'Budget Overview',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ),
          const SizedBox(height: 16),
          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (spentRatio > 0)
                    Flexible(
                      flex: (spentRatio * 1000).toInt(),
                      child: Container(color: _kRed),
                    ),
                  if (savedRatio > 0)
                    Flexible(
                      flex: (savedRatio * 1000).toInt(),
                      child: Container(color: _kGreen),
                    ),
                  if (spentRatio + savedRatio < 1.0)
                    Flexible(
                      flex: ((1.0 - spentRatio - savedRatio) * 1000).toInt().clamp(1, 1000),
                      child: Container(color: cs.outline.withValues(alpha: 0.12)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend row
          Row(
            children: [
              _BudgetLegendDot(color: _kRed,   label: 'Spent',  value: '${(spentRatio * 100).toInt()}%'),
              const SizedBox(width: 16),
              _BudgetLegendDot(color: _kGreen, label: 'Saved',  value: '${(savedRatio * 100).toInt()}%'),
              const Spacer(),
              Text(
                income > 0 ? '$percent% of income used' : 'No income recorded',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _BudgetLegendDot({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }
}

// -- _CategoryBudgetsSection -----------------------------------------------

class _CategoryBudgetsSection extends StatelessWidget {
  final Map<String, double> spending;
  final List<CategoryBudget> budgets;
  const _CategoryBudgetsSection({required this.spending, required this.budgets});

  static const _catColors = [_kIndigo, _kGreen, _kAmber, _kRed, _kTeal, _kPurple];

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final budgetMap = <String, double>{for (final b in budgets) b.category: b.budget};
    final allCategories = {...spending.keys, ...budgetMap.keys}.toList()
      ..sort((a, b) => (spending[b] ?? 0).compareTo(spending[a] ?? 0));
    final topCategories = allCategories.take(3).toList();

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context, 'Top Categories',
            trailing: allCategories.length > 3
                ? _viewAllChip(context, () => context.push('/personal/budgets'))
                : null,
          ),
          const SizedBox(height: 16),
          ...topCategories.asMap().entries.map((entry) {
            final cat         = entry.value;
            final accent      = _catColors[entry.key % _catColors.length];
            final spent       = spending[cat] ?? 0;
            final budget      = budgetMap[cat] ?? 0;
            final ratio       = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
            final percent     = (ratio * 100).toInt();
            final statusColor = percent <= 70 ? _kGreen : percent <= 100 ? _kAmber : _kRed;
            final isLast      = entry.key == topCategories.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.label_rounded, size: 14, color: accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                budget > 0 ? '₹${spent.toStringAsFixed(0)} of ₹${budget.toStringAsFixed(0)}' : '₹${spent.toStringAsFixed(0)} spent',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: budget > 0 ? statusColor : cs.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (budget > 0)
                          SizedBox(
                            width: 44, height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: ratio,
                                  strokeWidth: 4,
                                  backgroundColor: cs.outline.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                  strokeCap: StrokeCap.round,
                                ),
                                Text('$percent%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                              ],
                            ),
                          )
                        else
                          Text('No budget', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// -- _SpendingPieChart -----------------------------------------------------

class _SpendingPieChart extends StatelessWidget {
  final Map<String, double> spending;
  const _SpendingPieChart({required this.spending});

  static const _colors = [_kBlue, _kGreen, _kAmber, _kPurple, _kRed, _kTeal, _kIndigo, Color(0xFFEC4899)];

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final entries = spending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total   = entries.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Spending Breakdown'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110, height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 28,
                    sections: entries.asMap().entries.map((e) => PieChartSectionData(
                      value: e.value.value,
                      color: _colors[e.key % _colors.length],
                      title: '',
                      radius: 36,
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.take(5).map((e) {
                    final idx   = entries.indexOf(e);
                    final pct   = (e.value / total * 100).toInt();
                    final color = _colors[idx % _colors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(e.key, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
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
    );
  }
}

// -- _RecentTransactionsSection --------------------------------------------

class _RecentTransactionsSection extends StatelessWidget {
  final List<PersonalTransactionModel> transactions;
  final String monthKey;
  const _RecentTransactionsSection({required this.transactions, required this.monthKey});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context, 'Recent Transactions',
            trailing: _viewAllChip(context, () => context.push('/personal/transactions', extra: monthKey)),
          ),
          const SizedBox(height: 14),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.receipt_long_outlined, size: 26, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 10),
                    Text('No transactions yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...transactions.asMap().entries.map((entry) {
              final txn         = entry.value;
              final isLast      = entry.key == transactions.length - 1;
              final isIncome    = txn.isIncome;
              final accentColor = isIncome ? _kGreen : _kRed;
              final sign        = isIncome ? '+' : '-';
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: InkWell(
                  onTap: () => showPersonalTransactionDetail(context, txn),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.07 : 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accentColor.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(isIncome ? Icons.south_rounded : Icons.north_rounded, size: 16, color: accentColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${txn.category} • ${DateFormat('dd MMM').format(txn.date)}',
                                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$sign₹${txn.amount.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: accentColor),
                            ),
                            if (txn.personName != null && txn.personName!.isNotEmpty)
                              Text(txn.personName!, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// -- _RecurringSection -------------------------------------------------------

class _RecurringSection extends StatelessWidget {
  final List<RecurringTransaction> items;
  const _RecurringSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context, 'Recurring',
            trailing: _viewAllChip(context, () => context.push('/personal/recurring')),
          ),
          const SizedBox(height: 14),
          ...items.take(3).toList().asMap().entries.map((entry) {
            const palette = [_kTeal, _kPurple, _kBlue, _kIndigo, _kAmber, _kGreen];
            final r       = entry.value;
            final accent  = r.active ? palette[entry.key % palette.length] : cs.onSurface.withValues(alpha: 0.35);
            final isLast  = entry.key == items.take(3).length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.07 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        r.active ? Icons.autorenew_rounded : Icons.pause_circle_outline,
                        size: 18, color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                          Text(
                            '${r.frequency.name} • Day ${r.dayOfMonth}',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${r.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                        if (!r.active)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Paused', style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// -- _DebtsSummarySection ----------------------------------------------------

class _DebtsSummarySection extends ConsumerWidget {
  const _DebtsSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final balances = ref.watch(personalDebtBalancesProvider);
    double totalLent = 0;
    double totalOwed = 0;
    for (final v in balances.values) {
      if (v > 0) totalLent += v;
      else totalOwed += v.abs();
    }

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context, 'Debts',
            trailing: _viewAllChip(context, () => context.push('/personal/debt-dashboard')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _DebtStatTile(label: 'You Lent', amount: totalLent, color: _kGreen, icon: Icons.arrow_upward_rounded,   isDark: isDark, cs: cs)),
              const SizedBox(width: 10),
              Expanded(child: _DebtStatTile(label: 'You Owe',  amount: totalOwed, color: _kRed,   icon: Icons.arrow_downward_rounded, isDark: isDark, cs: cs)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebtStatTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isDark;
  final ColorScheme cs;
  const _DebtStatTile({
    required this.label, required this.amount, required this.color,
    required this.icon, required this.isDark, required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- _LoanSummarySection -----------------------------------------------------

class _LoanSummarySection extends ConsumerWidget {
  const _LoanSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final summary = ref.watch(loanSummaryProvider);
    if (summary.activeCount == 0) return const SizedBox.shrink();

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context, 'Loans & EMI',
            trailing: _viewAllChip(context, () => context.push('/personal/loans')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _DebtStatTile(label: 'Outstanding', amount: summary.totalOutstanding, color: _kRed,   icon: Icons.account_balance_wallet_rounded, isDark: isDark, cs: cs)),
              const SizedBox(width: 10),
              Expanded(child: _DebtStatTile(label: 'Monthly EMI', amount: summary.totalMonthlyEmi,  color: _kAmber, icon: Icons.calendar_month_rounded,          isDark: isDark, cs: cs)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kIndigo.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kIndigo.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: _kIndigo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_rounded, size: 16, color: _kIndigo),
                ),
                const SizedBox(width: 10),
                Text('${summary.activeCount} active loan${summary.activeCount > 1 ? "s" : ""}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _kIndigo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kIndigo)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- _StatBox (delegates to _DebtStatTile) -----------------------------------

class _StatBox extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _StatBox({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _DebtStatTile(label: label, amount: amount, color: color, icon: icon, isDark: isDark, cs: cs);
  }
}

// -- _WeeklyExpenseSummaryCard -----------------------------------------------

class _WeeklyExpenseSummaryCard extends ConsumerWidget {
  final String monthKey;
  const _WeeklyExpenseSummaryCard({required this.monthKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns   = ref.watch(personalTransactionsProvider(monthKey)).valueOrNull ?? [];
    final cs     = Theme.of(context).colorScheme;

    final parts = monthKey.split('-');
    final year  = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now   = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;

    final weekRanges = [(1, 7), (8, 14), (15, 21), (22, daysInMonth)];
    final weekExpenses = weekRanges.map((r) {
      return txns.where((t) => t.isExpense && t.date.day >= r.$1 && t.date.day <= r.$2)
          .fold<double>(0, (s, t) => s + t.amount);
    }).toList();

    final totalExpense = weekExpenses.fold<double>(0, (s, e) => s + e);
    final maxExpense   = weekExpenses.isEmpty ? 1.0 : weekExpenses.reduce((a, b) => a > b ? a : b);
    final avgWeekly    = totalExpense / 4;

    // Current week index (0-based)
    int currentWeekIdx = -1;
    if (isCurrentMonth) {
      for (int i = 0; i < weekRanges.length; i++) {
        if (now.day >= weekRanges[i].$1 && now.day <= weekRanges[i].$2) {
          currentWeekIdx = i;
          break;
        }
      }
    }

    if (totalExpense == 0) return const SizedBox.shrink();

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context, 'Weekly Spending',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Avg ₹${_fmtCompact(avgWeekly)}/wk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weekExpenses.asMap().entries.map((entry) {
              final i       = entry.key;
              final amount  = entry.value;
              final ratio   = maxExpense > 0 ? amount / maxExpense : 0.0;
              final isCurrent = i == currentWeekIdx;
              final isHighest = amount == maxExpense && amount > 0;
              final barColor  = isCurrent
                  ? cs.primary
                  : isHighest
                      ? _kRed
                      : cs.primary.withValues(alpha: 0.45);
              final barHeight = 60.0 * ratio.clamp(0.05, 1.0);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (amount > 0)
                        Text(
                          _fmtCompact(amount),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: barColor),
                        ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        child: Container(height: barHeight, color: barColor),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'W${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                          color: isCurrent ? cs.primary : cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          width: 4, height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Trend insight
          Builder(builder: (context) {
            if (currentWeekIdx > 0) {
              final prev = weekExpenses[currentWeekIdx - 1];
              final curr = weekExpenses[currentWeekIdx];
              if (prev > 0) {
                final diff = ((curr - prev) / prev * 100).toInt();
                final isUp = diff > 0;
                return Row(
                  children: [
                    Icon(
                      isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: isUp ? _kRed : _kGreen,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isUp
                          ? 'This week is ${diff.abs()}% more than last week'
                          : 'This week is ${diff.abs()}% less than last week',
                      style: TextStyle(fontSize: 11, color: isUp ? _kRed : _kGreen, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              }
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  String _fmtCompact(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// -- _QuickActionsRow ------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final String monthKey;
  const _QuickActionsRow({required this.monthKey});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionCard(icon: Icons.add_circle_outline_rounded,    label: 'Add',        color: _kGreen,  onTap: () => showAddPersonalTransactionSheet(context)),
      _QuickActionCard(icon: Icons.receipt_long_rounded,          label: 'Txns',       color: _kBlue,   onTap: () => context.push('/personal/transactions', extra: monthKey)),
      _QuickActionCard(icon: Icons.pie_chart_outline_rounded,     label: 'Budgets',    color: _kIndigo, onTap: () => context.push('/personal/budgets')),
      _QuickActionCard(icon: Icons.bar_chart_rounded,             label: 'Reports',    color: _kAmber,  onTap: () => showPersonalReportsSheet(context, monthKey)),
      _QuickActionCard(icon: Icons.handshake_outlined,            label: 'Debts',      color: _kTeal,   onTap: () => context.push('/personal/debt-dashboard')),
      _QuickActionCard(icon: Icons.autorenew_rounded,             label: 'Recurring',  color: _kPurple, onTap: () => context.push('/personal/recurring')),
      _QuickActionCard(icon: Icons.account_balance_rounded,        label: 'Loans',      color: _kRed,    onTap: () => context.push('/personal/loans')),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => actions[i],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
