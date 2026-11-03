import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/domain/policies/debts/debt_tally.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_commands.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'debt_widgets.dart';

String _money(int cents) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: cents % 100 == 0 ? 0 : 2,
).format(cents / 100);

String _remainingLabel(DebtTallyPlan plan) => plan.netCents > 0
    ? 'After tally: ${_money(plan.netCents)} to receive'
    : plan.netCents < 0
    ? 'After tally: ${_money(-plan.netCents)} to repay'
    : 'After tally: both sides settled';

class DebtTallySection extends StatelessWidget {
  final List<PersonalTransaction> debts;
  const DebtTallySection({super.key, required this.debts});

  @override
  Widget build(BuildContext context) {
    final people = <String, String>{};
    for (final debt in debts) {
      if (!isActiveTallyDebt(debt)) continue;
      people.putIfAbsent(
        debtPersonKey(debt.personName!),
        () => debt.personName!.trim(),
      );
    }
    final plans =
        [
            for (final person in people.values) planDebtTally(person, debts),
          ].where((plan) => plan.canTally).toList()
          ..sort((a, b) => a.personName.compareTo(b.personName));
    if (plans.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.base),
      child: Container(
        decoration: appCardDecoration(context),
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(title: 'Tally opposite debts'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Match balances with the same person. No money moves.',
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = plans.length == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth * .92).clamp(220.0, 340.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < plans.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: width,
                          child: AppFinanceTile(
                            icon: Icons.balance_rounded,
                            title: plans[i].personName,
                            subtitle: plans[i].netCents > 0
                                ? '${_money(plans[i].netCents)} left to receive'
                                : plans[i].netCents < 0
                                ? '${_money(-plans[i].netCents)} left to repay'
                                : 'No balance left after tally',
                            value: _money(plans[i].offsetCents),
                            detail: 'To offset',
                            color: cs.primary,
                            onTap: () => showDebtTallySheet(
                              context,
                              plans[i].personName,
                            ),
                            action: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: .3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void showDebtTallySheet(BuildContext context, String personName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DebtTallySheet(personName: personName),
  );
}

class _DebtTallySheet extends ConsumerStatefulWidget {
  final String personName;
  const _DebtTallySheet({required this.personName});

  @override
  ConsumerState<_DebtTallySheet> createState() => _DebtTallySheetState();
}

class _DebtTallySheetState extends ConsumerState<_DebtTallySheet> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm(DebtTallyPlan preview) async {
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tallyPersonalDebtsProvider)(
        userId,
        widget.personName,
        expectedOffsetCents: preview.offsetCents,
        expectedNetCents: preview.netCents,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debts tallied. No payment was recorded.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personalDebtTransactionsProvider);
    final debts = state.valueOrNull ?? const <PersonalTransaction>[];
    final plan = planDebtTally(widget.personName, debts);
    final cs = Theme.of(context).colorScheme;
    final ready = !state.isLoading && !state.hasError;
    final affected =
        debts.where((debt) => isActiveTallyDebt(debt) && plan.offsetsCents.containsKey(debt.id)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return DebtSheetFrame(
      title: 'Tally with ${widget.personName}',
      subtitle: 'Review matching balances · No money moves',
      icon: Icons.balance_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: !ready
                ? Center(
                    child: state.hasError
                        ? TextButton.icon(
                            onPressed: () => ref.invalidate(
                              personalDebtTransactionsProvider,
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Could not load debts · Retry'),
                          )
                        : const CircularProgressIndicator(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    children: [
                      Text(
                        'Only active balances are matched, oldest debts first. A debt stays partially settled if its remaining balance is not fully covered.',
                        style: AppTextStyles.bodySmall(
                          context,
                        ).copyWith(height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Container(
                        decoration: appCardDecoration(context),
                        padding: const EdgeInsets.all(AppSpacing.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionHeader(title: 'Tally preview'),
                            const SizedBox(height: AppSpacing.md),
                            AppFinanceTile(
                              icon: Icons.call_made_rounded,
                              title: 'They owe you',
                              subtitle: 'Outstanding lent balance',
                              value: _money(plan.lentCents),
                              color: AppColors.success(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppFinanceTile(
                              icon: Icons.call_received_rounded,
                              title: 'You owe them',
                              subtitle: 'Outstanding borrowed balance',
                              value: _money(plan.borrowedCents),
                              color: AppColors.error(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppFinanceTile(
                              icon: Icons.balance_rounded,
                              title: 'Offset now',
                              subtitle: 'Applied to both sides',
                              value: _money(plan.offsetCents),
                              color: cs.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _remainingLabel(plan),
                              style: AppTextStyles.label(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const AppSectionHeader(title: 'Debts affected'),
                      const SizedBox(height: AppSpacing.md),
                      for (final debt in affected) ...[
                        AppFinanceTile(
                          icon: debt.debtType == DebtType.lent
                              ? Icons.call_made_rounded
                              : Icons.call_received_rounded,
                          title: debt.title,
                          subtitle:
                              '${debt.debtType == DebtType.lent ? 'Lent' : 'Borrowed'} · Active: ${_money(roundedMoneyCents(debt.remainingAmount))}',
                          value: '−${_money(plan.offsetsCents[debt.id]!)}',
                          detail: 'Offset',
                          badges: Text(
                            roundedMoneyCents(debt.remainingAmount) > plan.offsetsCents[debt.id]!
                                ? 'After tally: ${_money(roundedMoneyCents(debt.remainingAmount) - plan.offsetsCents[debt.id]!)} left · Partially settled'
                                : 'After tally: ₹0 left · Settled',
                            style: AppTextStyles.caption(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          color: debt.debtType == DebtType.lent
                              ? AppColors.success(context)
                              : AppColors.error(context),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (!plan.canTally)
                        Text(
                          'No opposing balances remain to tally.',
                          style: AppTextStyles.bodySmall(context),
                        ),
                      if (_error != null)
                        Text(_error!, style: TextStyle(color: cs.error)),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: FilledButton.icon(
                onPressed: !ready || !plan.canTally || _busy
                    ? null
                    : () => _confirm(plan),
                icon: _busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.balance_rounded, size: 18),
                label: Text(_busy ? 'Tallying…' : 'Confirm Tally'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
