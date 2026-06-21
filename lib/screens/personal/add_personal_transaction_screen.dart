import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';

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
  ConsumerState<_AddPersonalTransactionSheet> createState() => _AddPersonalTransactionSheetState();
}

class _AddPersonalTransactionSheetState extends ConsumerState<_AddPersonalTransactionSheet> {
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
  DebtType _debtType = DebtType.lent;

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
    setState(() => _saving = true);

    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;

    final txn = PersonalTransactionModel(
      id: '',
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      type: _type,
      category: _category,
      date: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      userId: userId,
      month: DateFormat('yyyy-MM').format(_date),
      createdAt: DateTime.now(),
      debtType: _involvesPerson ? _debtType : null,
      personName: _involvesPerson ? _personCtrl.text.trim() : null,
    );

    await ref.read(personalExpenseServiceProvider).addTransaction(userId, txn);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Form(
            key: _formKey,
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
                // Header
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Add Transaction',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Type toggle
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.arrow_upward, size: 16)),
                    ButtonSegment(value: TransactionType.income, label: Text('Income'), icon: Icon(Icons.arrow_downward, size: 16)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),

                // Amount
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
                  autofocus: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Dinner, Uber, Salary',
                    prefixIcon: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Category & Date row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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

                // Debt toggle
                SwitchListTile(
                  value: _involvesPerson,
                  onChanged: (v) => setState(() => _involvesPerson = v),
                  title: const Text('Involves someone else?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  secondary: Icon(Icons.people_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  dense: true,
                ),

                if (_involvesPerson) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<DebtType>(
                    segments: const [
                      ButtonSegment(value: DebtType.lent, label: Text('I Lent'), icon: Icon(Icons.call_made, size: 16)),
                      ButtonSegment(value: DebtType.borrowed, label: Text('I Borrowed'), icon: Icon(Icons.call_received, size: 16)),
                    ],
                    selected: {_debtType},
                    onSelectionChanged: (s) => setState(() => _debtType = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _personCtrl,
                    decoration: InputDecoration(
                      labelText: 'Person\'s name',
                      hintText: 'e.g. John, Sarah',
                      prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    validator: (v) => _involvesPerson && (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Save
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Transaction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
