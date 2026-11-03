import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_commands.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/add_personal_transaction_screen.dart';
import 'package:split_ex/modules/personal/presentation/accounts/widgets/personal_account_picker.dart';
import 'package:split_ex/modules/personal/presentation/debts/widgets/debt_due_date_picker.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

void showAddDebtSheet(BuildContext context, {String? initialMonth}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddDebtSheet(initialMonth: initialMonth),
  );
}

class _AddDebtSheet extends ConsumerStatefulWidget {
  final String? initialMonth;
  const _AddDebtSheet({this.initialMonth});

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _personFocus = FocusNode();

  DebtType _debtType = DebtType.lent;
  String _category = 'Other';
  late DateTime _date;
  bool _saving = false;
  bool _showSuggestions = false;
  String? _accountId;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialMonth != null) {
      final parts = widget.initialMonth!.split('-');
      _date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final now = DateTime.now();
      if (_date.year == now.year && _date.month == now.month) _date = now;
    } else {
      _date = DateTime.now();
    }
    _personFocus.addListener(() {
      setState(() => _showSuggestions = _personFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _personCtrl.dispose();
    _personFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;

    final txnType = _debtType == DebtType.lent
        ? TransactionType.expense
        : TransactionType.income;

    final txn = PersonalTransaction(
      id: '',
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      type: txnType,
      category: _category,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      userId: userId,
      month: DateFormat('yyyy-MM').format(_date),
      createdAt: DateTime.now(),
      accountId: _accountId,
      dueDate: _dueDate,
      debtType: _debtType,
      personName: _personCtrl.text.trim(),
    );

    try {
      await ref.read(createPersonalTransactionProvider)(userId, txn);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your details and retry.')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_debtType == DebtType.lent ? 'Debt lent recorded' : 'Debt borrowed recorded')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suggestions = ref.watch(debtPersonSuggestionsProvider);
    final query = _personCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? suggestions
        : suggestions.where((s) => s.toLowerCase().contains(query)).toList();

    final isLent = _debtType == DebtType.lent;
    final accentColor = isLent ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    return PersonalFormSheet(
      title: 'Add Debt',
      icon: isLent ? Icons.call_made_rounded : Icons.call_received_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lent / Borrowed toggle
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _TypeTab(label: 'I Lent', icon: Icons.call_made_rounded, color: const Color(0xFF10B981), selected: isLent, onTap: () => setState(() => _debtType = DebtType.lent)),
                  _TypeTab(label: 'I Borrowed', icon: Icons.call_received_rounded, color: const Color(0xFFF43F5E), selected: !isLent, onTap: () => setState(() => _debtType = DebtType.borrowed)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Person name + suggestions
            TextFormField(
              controller: _personCtrl,
              focusNode: _personFocus,
              decoration: const InputDecoration(
                labelText: 'Person\'s name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            if (_showSuggestions && filtered.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: filtered.take(5).map((name) => InkWell(
                    onTap: () {
                      _personCtrl.text = name;
                      _personFocus.unfocus();
                      setState(() => _showSuggestions = false);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: accentColor.withValues(alpha: 0.12),
                            child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
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
                    items: personalCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _DebtDateButton(
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
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: AppSpacing.md),

            DebtDueDatePicker(
              value: _dueDate,
              debtDate: _date,
              enabled: !_saving,
              onChanged: (v) => setState(() => _dueDate = v),
            ),
            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // Balance impact hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: accentColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: accentColor),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isLent
                          ? 'Lent amount deducts from your balance. Returns when settled.'
                          : 'Borrowed amount adds to your balance. Settlement will deduct it.',
                      style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: accentColor),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isLent ? 'Record Lent' : 'Record Borrowed', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtDateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DebtDateButton({required this.date, required this.onTap});

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
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.55)),
            const SizedBox(width: 6),
            Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: selected ? Border.all(color: color.withValues(alpha: 0.35)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? color : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
