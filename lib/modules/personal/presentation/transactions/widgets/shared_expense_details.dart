import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

class SharedExpenseDetails extends StatelessWidget {
  final PersonalTransaction transaction;
  final bool expanded;
  const SharedExpenseDetails({
    super.key,
    required this.transaction,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final txn = transaction;
    if (!txn.hasSharedExpense) return const SizedBox.shrink();
    final cs          = Theme.of(context).colorScheme;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final statusColor = txn.sharedStatus == 'Settled'
        ? AppColors.success(context)
        : AppColors.warning(context);
    final shares      = txn.split!.shares;

    String personLine(ExpenseSplitShare share) {
      final debt = txn.debtForShare(share);
      final closedWithoutRepayment = debt != null &&
          (debt.writtenOffAmount > 0 ||
              debt.settlements.any((e) => e.isTally));
      final status = debt == null
          ? 'Unavailable'
          : debt.remainingAmount == 0
          ? (closedWithoutRepayment ? 'Closed' : 'Settled')
          : '${_money(debt.remainingAmount)} pending';
      return '${share.personName}  ${_money(share.amount)}  ·  $status';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status badges ──────────────────────────────────────────────
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Badge(label: 'Shared', color: cs.primary),
              _Badge(label: txn.sharedStatus, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // ── Summary row ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isDark ? .08 : .05),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: 'Your share',
                    value: _money(txn.split!.ownShareCents(txn.amount) / 100),
                    color: cs.onSurface,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _SummaryItem(
                    label: 'Shared',
                    value: _money(txn.sharedAmount),
                    color: cs.onSurface,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _SummaryItem(
                    label: 'Repaid',
                    value: _money(txn.sharedRepaidAmount),
                    color: AppColors.success(context),
                  ),
                ),
              ],
            ),
          ),

          // ── Per-person rows (expanded view) ────────────────────────────
          if (expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final share in shares)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: AppSpacing.sm, top: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: .5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        personLine(share),
                        style: AppTextStyles.caption(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ] else if (shares.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              shares.take(2).map((s) => s.personName).join(', ') +
                  (shares.length > 2 ? ' +${shares.length - 2} more' : ''),
              style: AppTextStyles.caption(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 1),
      Text(label, style: AppTextStyles.caption(context)),
    ],
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 24,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    color: Theme.of(context).colorScheme.outline.withValues(alpha: .15),
  );
}
