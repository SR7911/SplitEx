import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/monthly_money_review.dart';
import 'package:split_ex/providers/monthly_money_review_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/view_personal_transaction_sheet.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';
import 'package:split_ex/widgets/personal_form_sheet.dart';

String _money(double n) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: n == n.roundToDouble() ? 0 : 2,
).format(n);

class MonthlyMoneyReviewScreen extends ConsumerStatefulWidget {
  final DateTime? initialMonth;
  const MonthlyMoneyReviewScreen({super.key, this.initialMonth});
  @override
  ConsumerState<MonthlyMoneyReviewScreen> createState() =>
      _MonthlyMoneyReviewScreenState();
}

class _MonthlyMoneyReviewScreenState
    extends ConsumerState<MonthlyMoneyReviewScreen> {
  late DateTime _month;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final selected = widget.initialMonth ?? now;
    _month = DateTime(selected.year, selected.month);
    if (_month.isAfter(DateTime(now.year, now.month)))
      _month = DateTime(now.year, now.month);
  }

  void _move(int n) =>
      setState(() => _month = DateTime(_month.year, _month.month + n));
  @override
  Widget build(BuildContext context) {
    final review = ref.watch(monthlyMoneyReviewProvider(_month));
    return Scaffold(
      appBar: const AppHeader(
        title: 'Monthly Money Review',
        showBack: true,
        showNotification: false,
      ),
      body: GradientBody(
        child: Column(
          children: [
            AppMonthSelector(
              selectedMonth: _month,
              onPrev: () => _move(-1),
              onNext: () => _move(1),
            ),
            Expanded(
              child: review.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () {
                      ref.invalidate(
                        personalTransactionsProvider(
                          DateFormat('yyyy-MM').format(_month),
                        ),
                      );
                      ref.invalidate(
                        personalTransactionsProvider(
                          DateFormat(
                            'yyyy-MM',
                          ).format(DateTime(_month.year, _month.month - 1)),
                        ),
                      );
                      ref.invalidate(
                        personalBudgetsProvider(
                          DateFormat('yyyy-MM').format(_month),
                        ),
                      );
                      ref.invalidate(personalDebtsProvider);
                    },
                    child: const Text('Could not load this review · Retry'),
                  ),
                ),
                data: (data) => _body(context, data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> children, {
    String? action,
    VoidCallback? onAction,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: appCardDecoration(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, actionLabel: action, onAction: onAction),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
  Widget _body(BuildContext context, MonthlyMoneyReview data) {
    final cs = Theme.of(context).colorScheme;
    final overBudget = data.budgets.where((b) => b.remaining < 0).length;
    String delta(CategoryReview c) => c.previous == 0
        ? (c.current == 0 ? 'No change' : 'No expenses in previous period')
        : '${c.difference >= 0 ? '+' : '−'}${_money(c.difference.abs())} (${c.percent!.abs().toStringAsFixed(0)}% ${c.difference >= 0 ? 'more' : 'less'})';
    Widget category(CategoryReview c) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppFinanceTile(
        icon: Icons.category_outlined,
        title: c.category,
        subtitle: 'Previous: ${_money(c.previous)}',
        value: _money(c.current),
        detail: c.previous == 0
            ? 'New this period'
            : '${c.percent!.abs().toStringAsFixed(0)}% ${c.difference >= 0 ? 'more' : 'less'}',
        color: c.difference > 0 ? AppColors.warning(context) : cs.primary,
        onTap: () => context.push(
          '/personal/transactions/category',
          extra: {
            'monthKey': DateFormat('yyyy-MM').format(_month),
            'category': c.category,
          },
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(context, data.inProgress ? 'Month So Far' : 'Month Summary', [
          Text(
            '${data.comparisonLabel}${data.inProgress ? ' · Through ${DateFormat('d MMM').format(data.currentEnd)}' : ''}',
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppMiniStatCard(
                  label: 'Recorded expenses',
                  value: _money(data.expenses),
                  icon: Icons.north_east,
                  color: AppColors.error(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppMiniStatCard(
                  label: 'Recorded income',
                  value: _money(data.income),
                  icon: Icons.south_west,
                  color: AppColors.success(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.previousExpenses == 0
                ? 'No expenses recorded in the previous comparison period.'
                : '${_money(data.difference.abs())} ${data.difference >= 0 ? 'more' : 'less'} in expenses (${data.percent!.abs().toStringAsFixed(1)}%).',
            style: AppTextStyles.bodySmall(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Includes personal entries such as lending, borrowing and settlements, consistent with your dashboard. Account transfers and goal progress are excluded.',
            style: AppTextStyles.caption(context).copyWith(height: 1.5),
          ),
        ]),
        const SizedBox(height: 20),
        _section(
          context,
          'Category Changes',
          [
            if (data.categories.isEmpty)
              const AppFinanceEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No category activity',
                subtitle: 'Recorded expenses will appear here.',
              ),
            ...data.categories.take(4).map(category),
            if (data.categories.isNotEmpty)
              Text(
                delta(data.categories.first),
                style: AppTextStyles.caption(context),
              ),
          ],
          action: data.categories.length > 4 ? 'View All' : null,
          onAction: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => PersonalFormSheet(
              title: 'Category changes',
              icon: Icons.bar_chart_outlined,
              child: Column(children: data.categories.map(category).toList()),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _section(
          context,
          'Budget Check',
          [
            Text(
              data.budgets.isEmpty
                  ? 'No category budgets set for this month.'
                  : '$overBudget ${overBudget == 1 ? 'category is' : 'categories are'} over the monthly budget.',
              style: AppTextStyles.bodySmall(context),
            ),
            const SizedBox(height: 12),
            for (final b in data.budgets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppFinanceTile(
                  icon: Icons.pie_chart_outline,
                  title: b.budget.category,
                  subtitle: '${_money(b.spent)} of ${_money(b.budget.budget)}',
                  value: _money(b.remaining.abs()),
                  detail: b.remaining < 0 ? 'Over budget' : 'Remaining',
                  color: b.remaining < 0
                      ? AppColors.error(context)
                      : cs.primary,
                ),
              ),
          ],
          action: 'Manage',
          onAction: () => context.push(
            '/personal/budgets',
            extra: DateFormat('yyyy-MM').format(_month),
          ),
        ),
        const SizedBox(height: 20),
        _section(context, 'Needs Attention', [
          AppFinanceTile(
            icon: Icons.label_outline,
            title:
                '${data.uncategorized.length} uncategorized ${data.uncategorized.length == 1 ? 'expense' : 'expenses'}',
            subtitle: 'Review entries in Other or without a category.',
            value: _money(data.uncategorized.fold(0.0, (n, t) => n + t.amount)),
            onTap: data.uncategorized.isEmpty
                ? null
                : () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Consumer(
                      builder: (context, ref, _) {
                        final latest =
                            ref
                                .watch(monthlyMoneyReviewProvider(_month))
                                .valueOrNull
                                ?.uncategorized ??
                            data.uncategorized;
                        return PersonalFormSheet(
                          title: 'Uncategorized expenses',
                          icon: Icons.label_outline,
                          child: Column(
                            children: [
                              if (latest.isEmpty)
                                const AppFinanceEmptyState(
                                  icon: Icons.done_all,
                                  title: 'All categorized',
                                  subtitle:
                                      'There are no entries left to review.',
                                ),
                              for (final t in latest)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AppFinanceTile(
                                    icon: Icons.receipt_long_outlined,
                                    title: t.title,
                                    subtitle: DateFormat(
                                      'd MMM',
                                    ).format(t.date),
                                    value: _money(t.amount),
                                    onTap: () => showPersonalTransactionDetail(
                                      context,
                                      t,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]),
        const SizedBox(height: 20),
        _section(context, 'Outstanding Debts Now', [
          Text(
            'Current balances across all months.',
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: 12),
          AppFinanceTile(
            icon: Icons.south_west,
            title: 'To receive',
            subtitle: 'Unsettled money you lent',
            value: _money(data.toReceiveNow),
            color: AppColors.success(context),
            onTap: () => context.push('/personal/debts?tab=0'),
          ),
          const SizedBox(height: 8),
          AppFinanceTile(
            icon: Icons.north_east,
            title: 'To repay',
            subtitle: 'Unsettled money you borrowed',
            value: _money(data.toRepayNow),
            color: AppColors.error(context),
            onTap: () => context.push('/personal/debts?tab=1'),
          ),
        ]),
        const SizedBox(height: 16),
      ],
    );
  }
}
