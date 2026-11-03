import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_controller.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

class PersonalToolsSection extends ConsumerWidget {
  final String? monthKey;
  const PersonalToolsSection({super.key, this.monthKey});

  static const _kTeal   = Color(0xFF14B8A6);
  static const _kIndigo = Color(0xFF6366F1);
  static const _kAmber  = Color(0xFFF59E0B);
  static const _kGreen  = Color(0xFF22C55E);
  static const _kPurple = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sms = ref.watch(bankSmsControllerProvider);

    Widget tool(
      IconData icon,
      Color accent,
      String title,
      String subtitle,
      String route, {
      Object? extra,
    }) => Expanded(
      child: Container(
        decoration: appCardDecoration(context, accentColor: accent),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => context.push(route, extra: extra),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? .15 : .1),
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface,
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
                _kTeal,
                'Accounts & Wallets',
                'Cash, banks & transfers',
                '/personal/accounts',
              ),
              const SizedBox(width: 12),
              tool(
                Icons.calendar_month_rounded,
                _kIndigo,
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
                _kAmber,
                'Monthly Money Review',
                '${DateFormat('MMM yyyy').format(DateTime.tryParse('$monthKey-01') ?? DateTime.now())} insights & checks',
                '/personal/money-review',
                extra: monthKey,
              ),
              const SizedBox(width: AppSpacing.md),
              tool(
                Icons.savings_outlined,
                _kGreen,
                'Savings Goals',
                'Plan, save & track progress',
                '/personal/goals',
              ),
            ],
          ),
        ),
        if (sms.supported) ...[
          const SizedBox(height: 12),
          Container(
            decoration: appCardDecoration(context, accentColor: _kPurple),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppFinanceTile(
              onTap: () => context.push('/personal/sms-review'),
              color: _kPurple,
              icon: Icons.sms_outlined,
              leading: Badge(
                isLabelVisible: sms.reviews.isNotEmpty,
                label: Text('${sms.reviews.length}'),
                child: Icon(Icons.sms_outlined, color: _kPurple, size: 17),
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
