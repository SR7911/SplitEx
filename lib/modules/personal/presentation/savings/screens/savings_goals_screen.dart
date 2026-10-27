import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:split_ex/modules/personal/domain/entities/savings/savings_goal.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/presentation/accounts/providers/personal_account_providers.dart';
import 'package:split_ex/modules/personal/presentation/savings/providers/savings_goal_providers.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/modules/personal/presentation/accounts/widgets/personal_account_picker.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';

String _money(double n) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: n == n.roundToDouble() ? 0 : 2,
).format(n);
int? _minor(String text) {
  final n = double.tryParse(text.trim());
  return n == null || !n.isFinite ? null : (n * 100).round();
}

void _editGoal(BuildContext context, [SavingsGoal? goal]) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalEditor(goal: goal),
    );

class SavingsGoalsScreen extends ConsumerStatefulWidget {
  const SavingsGoalsScreen({super.key});
  @override
  ConsumerState<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends ConsumerState<SavingsGoalsScreen> {
  bool _archived = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader(
      title: 'Savings Goals',
      showBack: true,
      showNotification: false,
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Add savings goal',
      onPressed: () => _editGoal(context),
      child: const Icon(Icons.add),
    ),
    body: GradientBody(
      child: ref
          .watch(savingsGoalsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(savingsGoalsProvider),
                child: const Text('Could not load goals · Retry'),
              ),
            ),
            data: (all) {
              final goals = all.where((g) => g.archived == _archived).toList();
              final active = all.where((g) => !g.archived).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Container(
                    decoration: appCardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(title: 'Tracked Savings'),
                        const SizedBox(height: 12),
                        Text(
                          _money(active.fold(0.0, (n, g) => n + g.saved)),
                          style: AppTextStyles.stat(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${active.where((g) => g.reached).length} of ${active.length} active goals reached',
                          style: AppTextStyles.bodySmall(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Goal progress records your savings plan. It does not move money or change account balances, income or expenses.',
                          style: AppTextStyles.caption(
                            context,
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Active'),
                        labelStyle: Theme.of(context).textTheme.labelMedium,
                        selected: !_archived,
                        onSelected: (_) => setState(() => _archived = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Archived'),
                        labelStyle: Theme.of(context).textTheme.labelMedium,
                        selected: _archived,
                        onSelected: (_) => setState(() => _archived = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (goals.isEmpty)
                    const AppFinanceEmptyState(
                      icon: Icons.savings_outlined,
                      title: 'No savings goals here',
                      subtitle:
                          'Tap + to create a goal for something you are saving toward.',
                    ),
                  for (final goal in goals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/personal/goals/${goal.id}'),
                        child: _GoalCard(goal: goal),
                      ),
                    ),
                ],
              );
            },
          ),
    ),
  );
}

class _GoalCard extends ConsumerWidget {
  final SavingsGoal goal;
  const _GoalCard({required this.goal});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = goal.reached
        ? AppColors.success(context)
        : Theme.of(context).colorScheme.primary;
    final accountName = ref
        .watch(personalAccountsProvider)
        .valueOrNull
        ?.where((a) => a.id == goal.accountId)
        .firstOrNull
        ?.name;
    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFinanceTile(
            icon: goal.reached
                ? Icons.check_circle_outline
                : Icons.savings_outlined,
            title: goal.title,
            subtitle: goal.archived
                ? 'Archived'
                : goal.reached
                ? 'Goal reached'
                : goal.targetDate == null
                ? 'No target date'
                : 'Target: ${DateFormat('d MMM yyyy').format(goal.targetDate!)}',
            value: '${(goal.progress * 100).round()}%',
            color: color,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: .1),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${_money(goal.saved)} saved of ${_money(goal.target)}',
                style: AppTextStyles.label(context),
              ),
              Text(
                '${_money(goal.remaining)} to go',
                style: AppTextStyles.caption(context),
              ),
            ],
          ),
          if (goal.accountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Account label: ${accountName ?? 'Assigned account'}',
                style: AppTextStyles.caption(context),
              ),
            ),
        ],
      ),
    );
  }
}

class SavingsGoalDetailScreen extends ConsumerWidget {
  final String goalId;
  const SavingsGoalDetailScreen({super.key, required this.goalId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: const AppHeader(
      title: 'Savings Goal',
      showBack: true,
      showNotification: false,
    ),
    body: GradientBody(
      child: ref
          .watch(savingsGoalsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(savingsGoalsProvider),
                child: const Text('Could not load goal · Retry'),
              ),
            ),
            data: (goals) {
              final goal = goals.where((g) => g.id == goalId).firstOrNull;
              if (goal == null)
                return const Center(
                  child: Text('This goal is no longer available.'),
                );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _GoalCard(goal: goal),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            textStyle: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(fontSize: 14),
                          ),
                          onPressed: goal.archived
                              ? null
                              : () => _entry(context, goal, false),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add savings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            textStyle: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(fontSize: 14),
                          ),
                          onPressed: goal.archived || goal.savedMinor == 0
                              ? null
                              : () => _entry(context, goal, true),
                          child: const Text('Withdraw'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _editGoal(context, goal),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit goal'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final uid = ref
                              .read(authStateProvider)
                              .valueOrNull
                              ?.uid;
                          if (uid == null) return;
                          try {
                            await ref
                                .read(savingsGoalRepositoryProvider)
                                .archive(uid, goal.id, !goal.archived);
                          } catch (_) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not update goal. Try again.',
                                  ),
                                ),
                              );
                          }
                        },
                        child: Text(
                          goal.archived ? 'Restore goal' : 'Archive goal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Progress only: no bank transfer or expense is created.',
                    style: AppTextStyles.caption(context),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: appCardDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const AppSectionHeader(title: 'Savings History'),
                        const SizedBox(height: 12),
                        ref
                            .watch(savingsEntriesProvider(goal.id))
                            .when(
                              loading: () => const LinearProgressIndicator(),
                              error: (_, _) => TextButton(
                                onPressed: () => ref.invalidate(
                                  savingsEntriesProvider(goal.id),
                                ),
                                child: const Text(
                                  'Could not load history · Retry',
                                ),
                              ),
                              data: (entries) => Column(
                                children: [
                                  if (entries.isEmpty)
                                    const AppFinanceEmptyState(
                                      icon: Icons.history,
                                      title: 'No savings recorded',
                                      subtitle:
                                          'Add a contribution to start tracking your progress.',
                                    ),
                                  for (final e in entries)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: AppFinanceTile(
                                        icon: e.amountMinor > 0
                                            ? Icons.add_circle_outline
                                            : Icons.remove_circle_outline,
                                        title: e.amountMinor > 0
                                            ? 'Contribution'
                                            : 'Withdrawal',
                                        subtitle:
                                            '${DateFormat('d MMM yyyy').format(e.date)}${e.note.isEmpty ? '' : ' · ${e.note}'}',
                                        value:
                                            '${e.amountMinor > 0 ? '+' : '−'}${_money(e.amountMinor.abs() / 100)}',
                                        color: e.amountMinor > 0
                                            ? AppColors.success(context)
                                            : AppColors.warning(context),
                                        action: IconButton(
                                          tooltip: 'Delete savings entry',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: goal.archived
                                              ? null
                                              : () async {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text(
                                                        'Delete savings entry?',
                                                      ),
                                                      content: const Text(
                                                        'The tracked amount saved will be recalculated.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Delete',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmed != true) return;
                                                  final uid = ref
                                                      .read(authStateProvider)
                                                      .valueOrNull
                                                      ?.uid;
                                                  if (uid == null) return;
                                                  try {
                                                    await ref
                                                        .read(
                                                          savingsGoalRepositoryProvider,
                                                        )
                                                        .removeEntry(
                                                          uid,
                                                          goal.id,
                                                          e.id,
                                                        );
                                                  } catch (_) {
                                                    if (context.mounted)
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Could not delete. If this contribution has been used, remove later withdrawals first.',
                                                          ),
                                                        ),
                                                      );
                                                  }
                                                },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    ),
  );
}

void _entry(BuildContext context, SavingsGoal goal, bool withdraw) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavingsEntryEditor(goal: goal, withdraw: withdraw),
    );

class _GoalEditor extends ConsumerStatefulWidget {
  final SavingsGoal? goal;
  const _GoalEditor({this.goal});
  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late final String _id;
  late final TextEditingController _title, _target;
  DateTime? _date;
  String? _account, _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _id = widget.goal?.id ?? const Uuid().v4();
    _title = TextEditingController(text: widget.goal?.title ?? '');
    _target = TextEditingController(
      text: widget.goal?.target.toStringAsFixed(2) ?? '',
    );
    _date = widget.goal?.targetDate;
    _account = widget.goal?.accountId;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = _minor(_target.text);
    if (_title.text.trim().isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Enter a goal name and a positive target.');
      return;
    }
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(savingsGoalRepositoryProvider)
          .save(
            uid,
            SavingsGoal(
              id: _id,
              title: _title.text.trim(),
              targetMinor: amount,
              targetDate: _date,
              accountId: _account,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Could not save goal. Check your account and connection.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PersonalFormSheet(
    title: widget.goal == null ? 'Add savings goal' : 'Edit savings goal',
    icon: Icons.savings_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Goal name',
            hintText: 'e.g. Trip, emergency fund',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Target amount',
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: 16),
        PersonalAccountPicker(
          value: _account,
          enabled: !_saving,
          onChanged: (v) => setState(() => _account = v),
        ),
        ListTile(
          leading: const Icon(Icons.event_outlined, size: 20),
          title: const Text('Target date (optional)'),
          subtitle: Text(
            _date == null
                ? 'No target date'
                : DateFormat('d MMM yyyy').format(_date!),
          ),
          trailing: _date == null
              ? null
              : IconButton(
                  tooltip: 'Clear target date',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _date = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
          onTap: _saving
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2200),
                  );
                  if (date != null && mounted) setState(() => _date = date);
                },
        ),
        Text(
          'An optional account is a label for your plan. Contributions only update this goal’s progress.',
          style: AppTextStyles.caption(context).copyWith(height: 1.5),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save goal'),
        ),
      ],
    ),
  );
}

class _SavingsEntryEditor extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final bool withdraw;
  const _SavingsEntryEditor({required this.goal, required this.withdraw});
  @override
  ConsumerState<_SavingsEntryEditor> createState() =>
      _SavingsEntryEditorState();
}

class _SavingsEntryEditorState extends ConsumerState<_SavingsEntryEditor> {
  final _id = const Uuid().v4(),
      _amount = TextEditingController(),
      _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = _minor(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a positive amount.');
      return;
    }
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(savingsGoalRepositoryProvider)
          .record(
            uid,
            widget.goal.id,
            SavingsEntry(
              id: _id,
              amountMinor: widget.withdraw ? -amount : amount,
              date: _date,
              note: _note.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = widget.withdraw
              ? 'Could not withdraw. Check the current saved amount and connection.'
              : 'Could not save. Check that the goal is active and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PersonalFormSheet(
    title: widget.withdraw ? 'Withdraw savings' : 'Add savings',
    icon: widget.withdraw
        ? Icons.remove_circle_outline
        : Icons.savings_outlined,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.goal.title, style: AppTextStyles.sectionHeader(context)),
        const SizedBox(height: 8),
        Text(
          'Updates goal progress only. Your account balance, income and expenses stay the same.',
          style: AppTextStyles.caption(context).copyWith(height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        ListTile(
          leading: const Icon(Icons.event_outlined, size: 20),
          title: const Text('Date'),
          subtitle: Text(DateFormat('d MMM yyyy').format(_date)),
          onTap: _saving
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null && mounted) setState(() => _date = date);
                },
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Saving…'
                : widget.withdraw
                ? 'Record withdrawal'
                : 'Record savings',
          ),
        ),
      ],
    ),
  );
}
