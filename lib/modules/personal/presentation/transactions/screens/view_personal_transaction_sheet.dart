import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction_edit.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_commands.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/add_personal_transaction_screen.dart';
import 'package:split_ex/modules/personal/presentation/accounts/providers/personal_account_providers.dart';
import 'package:split_ex/modules/personal/presentation/accounts/widgets/personal_account_picker.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_due_date_picker.dart';
import 'package:split_ex/modules/personal/presentation/transactions/widgets/expense_split_editor.dart';
import 'package:split_ex/modules/personal/presentation/transactions/widgets/shared_expense_details.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

void showPersonalTransactionDetail(
  BuildContext context,
  PersonalTransaction txn,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionDetailSheet(txn: txn),
  );
}

class _TransactionDetailSheet extends ConsumerStatefulWidget {
  final PersonalTransaction txn;
  const _TransactionDetailSheet({required this.txn});

  @override
  ConsumerState<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<_TransactionDetailSheet> {
  bool _editing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _personCtrl;
  late String _category;
  late TransactionType _type;
  late DateTime _date;
  bool _saving = false;
  late bool _involvesPerson;
  late bool _splitExpense;
  final _splitEditorKey = GlobalKey<ExpenseSplitEditorState>();
  late DebtType _debtType;
  String? _accountId;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.txn.title);
    _amountCtrl = TextEditingController(text: widget.txn.amount.toString());
    _notesCtrl = TextEditingController(text: widget.txn.notes ?? '');
    _personCtrl = TextEditingController(text: widget.txn.personName ?? '');
    _category = widget.txn.category;
    _type = widget.txn.type;
    _date = widget.txn.date;
    _accountId = widget.txn.accountId;
    _dueDate = widget.txn.dueDate;
    _involvesPerson = widget.txn.hasDebt;
    _splitExpense = widget.txn.split != null;
    _debtType = widget.txn.debtType ?? DebtType.lent;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty)
      return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) return;

    ExpenseSplit? split;
    try {
      split = _splitExpense ? _splitEditorKey.currentState!.buildSplit() : null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }

    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;
    setState(() => _saving = true);

    try {
      await ref.read(editPersonalTransactionProvider)(
        userId,
        widget.txn.id,
        PersonalTransactionEdit(
          title: _titleCtrl.text.trim(),
          amount: amount,
          type: _involvesPerson
              ? (_debtType == DebtType.lent
                    ? TransactionType.expense
                    : TransactionType.income)
              : _type,
          category: _category,
          date: _date,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          debtType: _involvesPerson ? _debtType : null,
          personName: _involvesPerson ? _personCtrl.text.trim() : null,
          isSettled: _involvesPerson ? widget.txn.isSettled : false,
          accountId: _accountId,
          dueDate: _involvesPerson || _splitExpense ? _dueDate : null,
          split: split,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Updated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "${widget.txn.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;
    try {
      await ref.read(deletePersonalTransactionProvider)(userId, widget.txn.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  Widget _optionSwitch({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      value: value,
      onChanged: _saving ? null : onChanged,
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle,
              style: TextStyle(
                  fontSize: 11, color: cs.onSurface.withValues(alpha: .6))),
      secondary:
          Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: .5)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final txn = widget.txn.hasSharedExpense
        ? ref
                .watch(
                  personalMonthDisplayTransactionsProvider(widget.txn.month),
                )
                .valueOrNull
                ?.where((entry) => entry.id == widget.txn.id)
                .firstOrNull ??
            widget.txn
        : widget.txn;

    if (_editing) return _buildEditMode(context, txn);

    // ── VIEW MODE ──
    final isNeutralLent = txn.debtType == DebtType.lent && txn.isSettled;
    final isIncome = txn.type == TransactionType.income &&
        txn.debtType != DebtType.borrowed;
    final amountColor = isNeutralLent
        ? AppColors.info(context)
        : isIncome
            ? AppColors.success(context)
            : AppColors.error(context);

    return PersonalFormSheet(
      title: 'Transaction Details',
      icon: Icons.receipt_long_rounded,
      trailing: txn.splitSourceId == null && txn.debtSourceId == null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: _delete,
                icon: Icon(Icons.delete_outline,
                    color: AppColors.error(context)),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ])
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: appCardDecoration(context),
            child: Column(
              children: [
                _ViewRow(
                    icon: Icons.title,
                    label: 'Title',
                    value: txn.title),
                _ViewRow(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Amount',
                  value: '₹${txn.amount.toStringAsFixed(0)}',
                  valueColor: amountColor,
                ),
                _ViewRow(
                  icon: isNeutralLent
                      ? Icons.handshake_outlined
                      : isIncome
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                  label: 'Type',
                  value: txn.debtType == DebtType.lent
                      ? 'Lent Debt'
                      : txn.debtType == DebtType.borrowed
                          ? 'Borrowed Debt'
                          : txn.type.name[0].toUpperCase() +
                              txn.type.name.substring(1),
                ),
                _ViewRow(
                    icon: Icons.label_outline_rounded,
                    label: 'Category',
                    value: txn.category),
                _ViewRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: DateFormat('dd MMM yyyy').format(txn.date),
                ),
                if (txn.accountId != null)
                  _ViewRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Account',
                    value: ref
                            .watch(personalAccountsProvider)
                            .valueOrNull
                            ?.where((a) => a.id == txn.accountId)
                            .firstOrNull
                            ?.name ??
                        'Assigned account',
                  ),
                if (txn.dueDate != null)
                  _ViewRow(
                    icon: Icons.event_outlined,
                    label: 'Repayment due',
                    value: DateFormat('dd MMM yyyy').format(txn.dueDate!),
                  ),
                if (txn.hasDebt) ...[
                  _ViewRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Person',
                      value: txn.personName!),
                  _ViewRow(
                    icon: txn.debtType == DebtType.lent
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded,
                    label: 'Debt',
                    value: txn.debtType == DebtType.lent
                        ? 'You Lent'
                        : 'You Borrowed',
                    valueColor: txn.debtType == DebtType.lent
                        ? AppColors.success(context)
                        : AppColors.error(context),
                  ),
                  _ViewRow(
                    icon: Icons.check_circle_outline,
                    label: 'Status',
                    value: txn.isSettled
                        ? (txn.writtenOffAmount > 0 ? 'Closed' : 'Settled')
                        : txn.settledAmount > 0 || txn.writtenOffAmount > 0
                            ? 'Partial · ₹${txn.remainingAmount.toStringAsFixed(2)} left'
                            : 'Outstanding · ₹${txn.remainingAmount.toStringAsFixed(2)} left',
                  ),
                ],
                if (txn.splitSourceId != null)
                  const _ViewRow(
                    icon: Icons.link_rounded,
                    label: 'Split share',
                    value: 'Edit the original expense to change this share',
                  ),
                if (txn.debtSourceId != null)
                  const _ViewRow(
                    icon: Icons.handshake_outlined,
                    label: 'Debt payment',
                    value: 'Recorded in the related debt history',
                  ),
                if (txn.notes != null && txn.notes!.isNotEmpty)
                  _ViewRow(
                      icon: Icons.notes_rounded,
                      label: 'Notes',
                      value: txn.notes!),
              ],
            ),
          ),
          if (txn.hasSharedExpense) ...[
            const SizedBox(height: AppSpacing.md),
            SharedExpenseDetails(transaction: txn, expanded: true),
            for (final share in txn.split!.shares)
              if (share.debtId?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push(
                        '/personal/debts?debtId=${Uri.encodeComponent(share.debtId!)}');
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('View ${share.personName}\'s debt'),
                ),
              ],
          ],
          if ((txn.hasDebt && !txn.isSettled) || txn.debtSourceId != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () {
                final debtId = txn.debtSourceId ?? txn.id;
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push(
                    '/personal/debts?debtId=${Uri.encodeComponent(debtId)}');
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View debt and settlement history'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditMode(BuildContext context, PersonalTransaction txn) {
    return PersonalFormSheet(
      title: 'Edit Transaction',
      icon: Icons.edit_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.north_rounded, size: 15),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
                icon: Icon(Icons.south_rounded, size: 15),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type != TransactionType.expense) _splitExpense = false;
            }),
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(
            controller: _amountCtrl,
            onChanged: (_) => setState(() {}),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: personalCategories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _TxnDateButton(
                date: _date,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PersonalAccountPicker(
            value: _accountId,
            enabled: !_saving,
            label: 'Account (optional)',
            showHelperText: false,
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.sm),
          _optionSwitch(
            title: 'Involves someone else?',
            icon: Icons.people_outline_rounded,
            value: _involvesPerson,
            onChanged: (v) => setState(() {
              _involvesPerson = v;
              if (v) _splitExpense = false;
            }),
          ),
          if (_involvesPerson) ...[
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DebtType>(
              segments: const [
                ButtonSegment(
                    value: DebtType.lent,
                    label: Text('I Lent'),
                    icon: Icon(Icons.call_made_rounded, size: 15)),
                ButtonSegment(
                    value: DebtType.borrowed,
                    label: Text('I Borrowed'),
                    icon: Icon(Icons.call_received_rounded, size: 15)),
              ],
              selected: {_debtType},
              onSelectionChanged: (s) =>
                  setState(() => _debtType = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _personCtrl,
              decoration: const InputDecoration(
                labelText: 'Person\'s name',
                hintText: 'e.g. John, Sarah',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DebtDueDatePicker(
              value: _dueDate,
              debtDate: _date,
              enabled: !_saving,
              onChanged: (v) => setState(() => _dueDate = v),
            ),
          ],
          if (_type == TransactionType.expense && !_involvesPerson) ...[
            _optionSwitch(
              title: 'Split with people',
              subtitle: 'Their shares become debts owed to you',
              icon: Icons.call_split_rounded,
              value: _splitExpense,
              onChanged: (v) => setState(() => _splitExpense = v),
            ),
            if (_splitExpense) ...[
              const SizedBox(height: AppSpacing.sm),
              ExpenseSplitEditor(
                key: _splitEditorKey,
                totalText: _amountCtrl.text,
                initialSplit: txn.split,
                enabled: !_saving,
              ),
              const SizedBox(height: AppSpacing.md),
              DebtDueDatePicker(
                value: _dueDate,
                debtDate: _date,
                enabled: !_saving,
                onChanged: (v) => setState(() => _dueDate = v),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _ViewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: .45)),
          const SizedBox(width: AppSpacing.md),
          Text(label,
              style: AppTextStyles.label(context)
                  .copyWith(color: cs.onSurface.withValues(alpha: .6))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: AppTextStyles.label(context).copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxnDateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _TxnDateButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outline.withValues(alpha: .15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: cs.onSurface.withValues(alpha: .55)),
            const SizedBox(width: 6),
            Text(DateFormat('dd MMM').format(date),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
