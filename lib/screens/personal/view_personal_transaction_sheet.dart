import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';

void showPersonalTransactionDetail(BuildContext context, PersonalTransactionModel txn) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransactionDetailSheet(txn: txn),
  );
}

class _TransactionDetailSheet extends ConsumerStatefulWidget {
  final PersonalTransactionModel txn;
  const _TransactionDetailSheet({required this.txn});

  @override
  ConsumerState<_TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends ConsumerState<_TransactionDetailSheet> {
  bool _editing = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late String _category;
  late TransactionType _type;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.txn.title);
    _amountCtrl = TextEditingController(text: widget.txn.amount.toStringAsFixed(0));
    _notesCtrl = TextEditingController(text: widget.txn.notes ?? '');
    _category = widget.txn.category;
    _type = widget.txn.type;
    _date = widget.txn.date;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;

    await ref.read(personalExpenseServiceProvider).updateTransaction(userId, widget.txn.id, {
      'title': _titleCtrl.text.trim(),
      'amount': amount,
      'type': _type.name,
      'category': _category,
      'date': Timestamp.fromDate(_date),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'month': DateFormat('yyyy-MM').format(_date),
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "${widget.txn.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;
    await ref.read(personalExpenseServiceProvider).deleteTransaction(userId, widget.txn.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == TransactionType.income;
    final color = isIncome ? Colors.green : Colors.red;
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
                width: 48, height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
                  ),
                ),
                if (!_editing) ...[
                  IconButton(onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                  IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete'),
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
                  _DetailRow(icon: Icons.title, label: 'Title', value: widget.txn.title),
                  _DetailRow(icon: Icons.currency_rupee, label: 'Amount', value: '₹${widget.txn.amount.toStringAsFixed(0)}', valueColor: color),
                  _DetailRow(icon: isIncome ? Icons.arrow_downward : Icons.arrow_upward, label: 'Type', value: _type.name.toUpperCase()),
                  _DetailRow(icon: Icons.category, label: 'Category', value: widget.txn.category),
                  _DetailRow(icon: Icons.calendar_today, label: 'Date', value: DateFormat('dd MMM yyyy').format(widget.txn.date)),
                  if (widget.txn.hasDebt) ...[
                    _DetailRow(icon: Icons.person, label: 'Person', value: widget.txn.personName!),
                    _DetailRow(
                      icon: widget.txn.debtType == DebtType.lent ? Icons.call_made : Icons.call_received,
                      label: 'Debt',
                      value: widget.txn.debtType == DebtType.lent ? 'You Lent' : 'You Borrowed',
                      valueColor: widget.txn.debtType == DebtType.lent ? Colors.green : Colors.red,
                    ),
                    _DetailRow(icon: Icons.check_circle_outline, label: 'Settled', value: widget.txn.isSettled ? 'Yes' : 'No'),
                  ],
                  if (widget.txn.notes != null && widget.txn.notes!.isNotEmpty)
                    _DetailRow(icon: Icons.notes, label: 'Notes', value: widget.txn.notes!),
                ],
              ),
            ] else ...[
              // Edit mode
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.arrow_upward, size: 16)),
                  ButtonSegment(value: TransactionType.income, label: Text('Income'), icon: Icon(Icons.arrow_downward, size: 16)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: personalCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) setState(() => _date = picked);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM').format(_date), style: const TextStyle(fontSize: 14)),
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
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _editing = false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      child: _saving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
  const _DetailCard({required this.color, required this.isDark, required this.children});

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
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}
