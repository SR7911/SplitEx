import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/services/bank_sms_service.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class PersonalToolsSection extends ConsumerWidget {
  final String? monthKey;
  const PersonalToolsSection({super.key, this.monthKey});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final sms = ref.watch(bankSmsServiceProvider);
    Widget tool(
      IconData icon,
      String title,
      String subtitle,
      String route, {
      Object? extra,
    }) => Expanded(
      child: Container(
        decoration: appCardDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(route, extra: extra),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cs.primary, size: 18),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: .5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tool(
                Icons.account_balance_wallet_outlined,
                'Accounts & Wallets',
                'Cash, banks & transfers',
                '/personal/accounts',
              ),
              const SizedBox(width: 12),
              tool(
                Icons.calendar_month_rounded,
                'Payment Calendar',
                'Your upcoming payment dates',
                '/personal/calendar',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tool(
                Icons.fact_check_outlined,
                'Monthly Money Review',
                '${DateFormat('MMM yyyy').format(DateTime.tryParse('$monthKey-01') ?? DateTime.now())} insights & checks',
                '/personal/money-review',
                extra: monthKey,
              ),
              const SizedBox(width: AppSpacing.md),
              tool(
                Icons.savings_outlined,
                'Savings Goals',
                'Plan, save & track progress',
                '/personal/goals',
              ),
            ],
          ),
        ),
        if (BankSmsService.supported) ...[
          const SizedBox(height: 12),
          Container(
            decoration: appCardDecoration(context),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppFinanceTile(
              onTap: () => context.push('/personal/sms-review'),
              icon: Icons.sms_outlined,
              leading: Badge(
                isLabelVisible: sms.reviews.isNotEmpty,
                label: Text('${sms.reviews.length}'),
                child: Icon(Icons.sms_outlined, color: cs.primary, size: 17),
              ),
              title: sms.reviews.isEmpty
                  ? 'SMS Review Inbox'
                  : '${sms.reviews.length} ${sms.reviews.length == 1 ? 'payment needs' : 'payments need'} review',
              subtitle: sms.pendingCount > 0
                  ? '${sms.pendingCount} messages awaiting processing'
                  : sms.enabled
                  ? 'Review detected payments before recording'
                  : 'Set up bank SMS recording',
              action: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: .3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
