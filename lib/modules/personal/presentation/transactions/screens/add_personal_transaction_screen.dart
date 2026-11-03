import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_commands.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/presentation/accounts/widgets/personal_account_picker.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_due_date_picker.dart';
import 'package:split_ex/modules/personal/presentation/transactions/widgets/expense_split_editor.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

const personalCategories = [
  'Food',
  'Transport',
  'Rent',
  'Entertainment',
  'Mobile Recharge',
  'Cosmetics',
  'Home',
  'Loan',
  'EMI',
  'Bills',
  'Fuel',
  'Salary',
  'Shopping',
  'Health',
  'Gifts',
  'Education',
  'Groceries',
  'Other',
];

void showAddPersonalTransactionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddPersonalTransactionSheet(),
  );
}

class _AddPersonalTransactionSheet extends ConsumerStatefulWidget {
  const _AddPersonalTransactionSheet();

  @override
  ConsumerState<_AddPersonalTransactionSheet> createState() =>
      _AddPersonalTransactionSheetState();
}

class _AddPersonalTransactionSheetState
    extends ConsumerState<_AddPersonalTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _personCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _category = 'Food';
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _involvesPerson = false;
  bool _splitExpense = false;
  final _splitEditorKey = GlobalKey<ExpenseSplitEditorState>();
  DebtType _debtType = DebtType.lent;
  String? _accountId;
  DateTime? _dueDate;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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

    final txn = PersonalTransaction(
      id: '',
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      type: _involvesPerson
          ? (_debtType == DebtType.lent
                ? TransactionType.expense
                : TransactionType.income)
          : _type,
      category: _category,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      userId: userId,
      month: DateFormat('yyyy-MM').format(_date),
      createdAt: DateTime.now(),
      accountId: _accountId,
      dueDate: _involvesPerson || _splitExpense ? _dueDate : null,
      debtType: _involvesPerson ? _debtType : null,
      personName: _involvesPerson ? _personCtrl.text.trim() : null,
      split: split,
    );

    try {
      await ref.read(createPersonalTransactionProvider)(userId, txn);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction added')));
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
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: .6))),
      secondary: Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: .5)),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PersonalFormSheet(
      title: 'Add Transaction',
      icon: Icons.add_circle_outline_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type toggle
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

            // Amount
            TextFormField(
              controller: _amountCtrl,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0)
                  return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Dinner, Uber, Salary',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Category + Date
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: personalCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _DateButton(
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

            // Account
            PersonalAccountPicker(
              value: _accountId,
              enabled: !_saving,
              label: 'Account (optional)',
              showHelperText: false,
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Involves person toggle
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
                  ButtonSegment(value: DebtType.lent,     label: Text('I Lent'),     icon: Icon(Icons.call_made_rounded,     size: 15)),
                  ButtonSegment(value: DebtType.borrowed, label: Text('I Borrowed'), icon: Icon(Icons.call_received_rounded, size: 15)),
                ],
                selected: {_debtType},
                onSelectionChanged: (s) => setState(() => _debtType = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _personCtrl,
                decoration: const InputDecoration(
                  labelText: 'Person\'s name',
                  hintText: 'e.g. John, Sarah',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => _involvesPerson && (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DebtDueDatePicker(
                value: _dueDate,
                debtDate: _date,
                enabled: !_saving,
                onChanged: (v) => setState(() => _dueDate = v),
              ),
            ],

            // Split toggle
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
            const SizedBox(height: AppSpacing.sm),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateButton({required this.date, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outline.withValues(alpha: .15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: cs.onSurface.withValues(alpha: .55)),
            const SizedBox(width: 6),
            Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
