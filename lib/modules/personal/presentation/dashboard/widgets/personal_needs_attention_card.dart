import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/providers/personal_attention_providers.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_controller.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

class PersonalNeedsAttentionCard extends ConsumerWidget {
  final DateTime? selectedMonth;
  const PersonalNeedsAttentionCard({super.key, this.selectedMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(personalAttentionTodayProvider);
    final selected = selectedMonth ?? today;
    final month = DateTime(selected.year, selected.month);
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final payments = ref.watch(personalAttentionPaymentsProvider(month));
    final budgets = ref.watch(personalAttentionBudgetsProvider(month));
    final sms = isCurrentMonth ? ref.watch(bankSmsControllerProvider) : null;
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];

    void row({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      VoidCallback? onTap,
      bool loading = false,
    }) {
      rows.add(
        AppFinanceTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          color: color,
          onTap: onTap,
          action: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: .3),
                ),
        ),
      );
    }

    if (payments.hasError) {
      row(
        icon: Icons.calendar_month_rounded,
        title: 'Couldn’t check upcoming payments',
        subtitle: 'Open Payment Calendar to review and retry',
        color: AppColors.warning(context),
        onTap: () => context.push('/personal/calendar', extra: month),
      );
    } else if (payments.isLoading) {
      row(
        icon: Icons.calendar_month_rounded,
        title: isCurrentMonth
            ? 'Checking upcoming payments'
            : 'Checking payments',
        subtitle: isCurrentMonth
            ? 'Today and the next six days'
            : DateFormat('MMMM yyyy').format(month),
        color: cs.primary,
        loading: true,
      );
    } else if (payments.requireValue.isNotEmpty) {
      final entries = payments.requireValue;
      final total = entries.fold(0.0, (sum, entry) => sum + entry.amount);
      final next = entries.first;
      row(
        icon: Icons.calendar_month_rounded,
        title:
            '${entries.length} ${entries.length == 1 ? 'payment' : 'payments'} ${isCurrentMonth ? 'due soon' : 'unrecorded'}',
        subtitle:
            '${_money(total)} ${isCurrentMonth ? 'scheduled · Next:' : 'unrecorded · From:'} ${DateFormat('d MMM').format(next.date)}',
        color: AppColors.warning(context),
        onTap: () => context.push('/personal/calendar', extra: next.date),
      );
    }

    if (sms != null && sms.supported && !sms.statusLoaded) {
      row(
        icon: Icons.sms_outlined,
        title: sms.error == null
            ? 'Checking bank messages'
            : 'Couldn’t check bank messages',
        subtitle: sms.error == null
            ? 'Loading your review inbox'
            : 'Open the inbox to check and retry',
        color: cs.primary,
        loading: sms.error == null,
        onTap: sms.error == null
            ? null
            : () => context.push('/personal/sms-review'),
      );
    } else if (sms != null &&
        sms.supported &&
        (sms.reviews.isNotEmpty || sms.pendingCount > 0 || sms.error != null)) {
      final count = sms.reviews.length;
      row(
        icon: Icons.sms_outlined,
        title: count > 0
            ? '$count ${count == 1 ? 'message needs' : 'messages need'} review'
            : sms.error != null
            ? 'Bank message review needs a check'
            : '${sms.pendingCount} ${sms.pendingCount == 1 ? 'message awaits' : 'messages await'} processing',
        subtitle: sms.error != null
            ? 'Open the inbox to check and retry'
            : 'Review detected payments before recording',
        color: cs.primary,
        onTap: () => context.push('/personal/sms-review'),
      );
    }

    final monthKey = DateFormat('yyyy-MM').format(month);
    if (budgets.hasError) {
      row(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Couldn’t check budget limits',
        subtitle: 'Open budgets to review and retry',
        color: AppColors.warning(context),
        onTap: () => context.push('/personal/budgets', extra: monthKey),
      );
    } else if (budgets.isLoading) {
      row(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Checking budget limits',
        subtitle: DateFormat('MMMM yyyy').format(month),
        color: cs.primary,
        loading: true,
      );
    } else if (budgets.requireValue.isNotEmpty) {
      final overruns = budgets.requireValue;
      final excess =
          overruns.fold(0, (sum, overrun) => sum + overrun.excessPaise) / 100;
      row(
        icon: Icons.pie_chart_outline_rounded,
        title: overruns.length == 1
            ? '${overruns.first.category} budget exceeded'
            : '${overruns.length} budgets exceeded',
        subtitle:
            '${_money(excess)} over${overruns.length > 1 ? ' in total' : ''} · ${DateFormat('MMM yyyy').format(month)}',
        color: AppColors.error(context),
        onTap: () => context.push('/personal/budgets', extra: monthKey),
      );
    }

    if (rows.isEmpty) {
      row(
        icon: Icons.check_circle_outline_rounded,
        title: 'Nothing needs attention',
        subtitle: isCurrentMonth
            ? 'No payments due in the next 7 days, pending messages or exceeded budgets.'
            : 'No unrecorded payments or exceeded budgets for ${DateFormat('MMM yyyy').format(month)}.',
        color: AppColors.success(context),
      );
    }

    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Needs attention'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isCurrentMonth
                ? 'Next 7 days · ${DateFormat('MMM yyyy').format(month)} budgets'
                : '${DateFormat('MMM yyyy').format(month)} · Unrecorded payments and budgets',
            style: AppTextStyles.caption(context),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            rows[i],
          ],
        ],
      ),
    );
  }

  String _money(double amount) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
  ).format(amount);
}
