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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNeutralLent =
        !_editing &&
        widget.txn.debtType == DebtType.lent &&
        widget.txn.isSettled;
    final isIncome =
        _type == TransactionType.income &&
        (_editing || widget.txn.debtType != DebtType.borrowed);
    final color = isNeutralLent
        ? Colors.blueGrey
        : isIncome
        ? Colors.green
        : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header with actions
            Row(
              children: [
                Icon(Icons.receipt_long, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _editing ? 'Edit Transaction' : 'Transaction Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                if (!_editing &&
                    widget.txn.splitSourceId == null &&
                    widget.txn.debtSourceId == null) ...[
                  IconButton(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            if (!_editing) ...[
              // View mode
              _DetailCard(
                color: color,
                isDark: isDark,
                children: [
                  _DetailRow(
                    icon: Icons.title,
                    label: 'Title',
                    value: widget.txn.title,
                  ),
                  _DetailRow(
                    icon: Icons.currency_rupee,
                    label: 'Amount',
                    value: '₹${widget.txn.amount.toStringAsFixed(0)}',
                    valueColor: color,
                  ),
                  _DetailRow(
                    icon: isNeutralLent
                        ? Icons.handshake_outlined
                        : isIncome
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    label: 'Type',
                    value: widget.txn.debtType == DebtType.lent
                        ? 'LENT DEBT'
                        : widget.txn.debtType == DebtType.borrowed
                        ? 'BORROWED DEBT'
                        : _type.name.toUpperCase(),
                  ),
                  _DetailRow(
                    icon: Icons.category,
                    label: 'Category',
                    value: widget.txn.category,
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('dd MMM yyyy').format(widget.txn.date),
                  ),
                  if (widget.txn.accountId != null)
                    _DetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Account',
                      value:
                          ref
                              .watch(personalAccountsProvider)
                              .valueOrNull
                              ?.where((a) => a.id == widget.txn.accountId)
                              .firstOrNull
                              ?.name ??
                          'Assigned account',
                    ),
                  if (widget.txn.dueDate != null)
                    _DetailRow(
                      icon: Icons.event_outlined,
                      label: 'Repayment due',
                      value: DateFormat(
                        'dd MMM yyyy',
                      ).format(widget.txn.dueDate!),
                    ),
                  if (widget.txn.hasDebt) ...[
                    _DetailRow(
                      icon: Icons.person,
                      label: 'Person',
                      value: widget.txn.personName!,
                    ),
                    _DetailRow(
                      icon: widget.txn.debtType == DebtType.lent
                          ? Icons.call_made
                          : Icons.call_received,
                      label: 'Debt',
                      value: widget.txn.debtType == DebtType.lent
                          ? 'You Lent'
                          : 'You Borrowed',
                      valueColor: widget.txn.debtType == DebtType.lent
                          ? Colors.green
                          : Colors.red,
                    ),
                    _DetailRow(
                      icon: Icons.check_circle_outline,
                      label: 'Debt status',
                      value: widget.txn.isSettled
                          ? (widget.txn.writtenOffAmount > 0
                                ? 'Closed'
                                : 'Settled')
                          : widget.txn.settledAmount > 0 ||
                                widget.txn.writtenOffAmount > 0
                          ? 'Partially settled · ₹${widget.txn.remainingAmount.toStringAsFixed(2)} remaining'
                          : 'Outstanding · ₹${widget.txn.remainingAmount.toStringAsFixed(2)} remaining',
                    ),
                  ],
                  if (widget.txn.split != null) ...[
                    _DetailRow(
                      icon: Icons.call_split_rounded,
                      label: 'Split',
                      value: widget.txn.split!.mode == ExpenseSplitMode.equal
                          ? 'Equal with ${widget.txn.split!.shares.length} people'
                          : 'Manual with ${widget.txn.split!.shares.length} people',
                    ),
                    for (final share in widget.txn.split!.shares)
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: share.personName,
                        value:
                            '₹${share.amount.toStringAsFixed(2)} owed to you',
                      ),
                    _DetailRow(
                      icon: Icons.account_circle_outlined,
                      label: 'Your share',
                      value:
                          '₹${(widget.txn.split!.ownShareCents(widget.txn.amount) / 100).toStringAsFixed(2)}',
                    ),
                  ],
                  if (widget.txn.splitSourceId != null)
                    const _DetailRow(
                      icon: Icons.link_rounded,
                      label: 'Split share',
                      value: 'Edit the original expense to change this share',
                    ),
                  if (widget.txn.debtSourceId != null)
                    const _DetailRow(
                      icon: Icons.handshake_outlined,
                      label: 'Debt payment',
                      value: 'Recorded in the related debt history',
                    ),
                  if (widget.txn.notes != null && widget.txn.notes!.isNotEmpty)
                    _DetailRow(
                      icon: Icons.notes,
                      label: 'Notes',
                      value: widget.txn.notes!,
                    ),
                ],
              ),
              if (widget.txn.hasDebt || widget.txn.debtSourceId != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final debtId = widget.txn.debtSourceId ?? widget.txn.id;
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push(
                      '/personal/debts?debtId=${Uri.encodeComponent(debtId)}',
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View debt and settlement history'),
                ),
              ],
            ] else ...[
              // Edit mode
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward, size: 16),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward, size: 16),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  if (_type != TransactionType.expense) _splitExpense = false;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(
                    Icons.currency_rupee,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(
                    Icons.receipt_long,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: personalCategories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM').format(_date),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Debt toggle
              PersonalAccountPicker(
                value: _accountId,
                enabled: !_saving,
                label: 'Account (optional)',
                showHelperText: false,
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _involvesPerson,
                onChanged: (v) => setState(() {
                  _involvesPerson = v;
                  if (v) _splitExpense = false;
                }),
                title: const Text(
                  'Involves someone else?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                secondary: Icon(
                  Icons.people_outline,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                dense: true,
              ),
              if (_involvesPerson) ...[
                DebtDueDatePicker(
                  value: _dueDate,
                  debtDate: _date,
                  enabled: !_saving,
                  onChanged: (v) => setState(() => _dueDate = v),
                ),
                const SizedBox(height: 12),
                SegmentedButton<DebtType>(
                  segments: const [
                    ButtonSegment(
                      value: DebtType.lent,
                      label: Text('I Lent'),
                      icon: Icon(Icons.call_made, size: 16),
                    ),
                    ButtonSegment(
                      value: DebtType.borrowed,
                      label: Text('I Borrowed'),
                      icon: Icon(Icons.call_received, size: 16),
                    ),
                  ],
                  selected: {_debtType},
                  onSelectionChanged: (s) =>
                      setState(() => _debtType = s.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _personCtrl,
                  decoration: InputDecoration(
                    labelText: 'Person\'s name',
                    hintText: 'e.g. John, Sarah',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              if (_type == TransactionType.expense && !_involvesPerson) ...[
                SwitchListTile(
                  value: _splitExpense,
                  onChanged: (value) => setState(() => _splitExpense = value),
                  title: const Text('Split with people'),
                  subtitle: const Text('Their shares become debts owed to you'),
                  secondary: const Icon(Icons.call_split_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                if (_splitExpense) ...[
                  ExpenseSplitEditor(
                    key: _splitEditorKey,
                    totalText: _amountCtrl.text,
                    initialSplit: widget.txn.split,
                    enabled: !_saving,
                  ),
                  const SizedBox(height: 12),
                  DebtDueDatePicker(
                    value: _dueDate,
                    debtDate: _date,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _dueDate = value),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _editing = false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Color color;
  final bool isDark;
  final List<Widget> children;
  const _DetailCard({
    required this.color,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.08) : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: 14,
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
