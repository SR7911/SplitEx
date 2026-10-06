import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.initialMonth != null) {
      final parts = widget.initialMonth!.split('-');
      _date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      // clamp to today if initialMonth is current month
      final now = DateTime.now();
      if (_date.year == now.year && _date.month == now.month) {
        _date = now;
      }
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

    // Lent = expense (deducts balance), Borrowed = income (adds to balance at creation)
    final txnType = _debtType == DebtType.lent
        ? TransactionType.expense
        : TransactionType.income;

    final txn = PersonalTransactionModel(
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
      debtType: _debtType,
      personName: _personCtrl.text.trim(),
    );

    await ref.read(personalExpenseServiceProvider).addTransaction(userId, txn);

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
    final accentColor = isLent ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 48, height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isLent ? Icons.call_made : Icons.call_received, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Add Debt', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 20),

                // Lent / Borrowed toggle
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _TypeTab(
                        label: 'I Lent',
                        icon: Icons.call_made,
                        color: const Color(0xFF22C55E),
                        selected: isLent,
                        onTap: () => setState(() => _debtType = DebtType.lent),
                      ),
                      _TypeTab(
                        label: 'I Borrowed',
                        icon: Icons.call_received,
                        color: const Color(0xFFEF4444),
                        selected: !isLent,
                        onTap: () => setState(() => _debtType = DebtType.borrowed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: _inputDeco(context, 'Amount (₹)', Icons.currency_rupee),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDeco(context, 'Description', Icons.notes),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Person name with suggestions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _personCtrl,
                      focusNode: _personFocus,
                      decoration: _inputDeco(context, 'Person\'s name', Icons.person_outline),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    if (_showSuggestions && filtered.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          children: filtered.take(5).map((name) => InkWell(
                            onTap: () {
                              _personCtrl.text = name;
                              _personFocus.unfocus();
                              setState(() => _showSuggestions = false);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: accentColor.withValues(alpha: 0.12),
                                    child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accentColor)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category & Date row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: _inputDeco(context, 'Category', Icons.category).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        items: personalCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd MMM').format(_date), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  decoration: _inputDeco(context, 'Notes (optional)', Icons.edit_note),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Balance impact hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isLent
                              ? 'Lent amount will be deducted from your balance. It returns when settled.'
                              : 'Borrowed amount adds to your balance. Settlement will deduct it.',
                          style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isLent ? 'Record Lent' : 'Record Borrowed', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDeco(BuildContext context, String label, IconData icon) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: cs.onSurface.withValues(alpha: 0.5)),
    filled: true,
    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  );
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
