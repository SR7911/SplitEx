import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

const _projectCategories = [
  'Materials', 'Labor', 'Services', 'Equipment', 'Transport',
  'Food & Catering', 'Decoration', 'Venue', 'Clothing & Attire',
  'Electronics', 'Furniture', 'Utilities', 'Fees & Permits',
  'Marketing', 'Miscellaneous',
];

void showAddProjectExpenseSheet(BuildContext context, {required String projectId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddProjectExpenseSheet(projectId: projectId),
  );
}

class _AddProjectExpenseSheet extends ConsumerStatefulWidget {
  final String projectId;
  const _AddProjectExpenseSheet({required this.projectId});

  @override
  ConsumerState<_AddProjectExpenseSheet> createState() => _AddProjectExpenseSheetState();
}

class _AddProjectExpenseSheetState extends ConsumerState<_AddProjectExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = _projectCategories.first;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      final expense = ProjectExpenseModel(
        id: '',
        projectId: widget.projectId,
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _category,
        vendor: _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        paymentMethod: _paymentMethod,
        date: _date,
        createdBy: uid,
        createdAt: DateTime.now(),
      );
      await ref.read(projectExpenseServiceProvider).addExpense(uid, expense);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                Center(
                  child: Container(
                    width: 48, height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('Add Expense', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 20),
                _field(_titleController, 'Title', Icons.receipt_long,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null),
                const SizedBox(height: 14),
                _field(_amountController, 'Amount (₹)', Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                      return null;
                    }),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: _dec('Category', Icons.category),
                        items: _projectCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _category = v!),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () async {
                        final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (p != null) setState(() => _date = p);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                            const SizedBox(width: 6),
                            Text(DateFormat('dd MMM').format(_date), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(_vendorController, 'Vendor (optional)', Icons.store_outlined),
                const SizedBox(height: 14),
                // Payment method
                Wrap(
                  spacing: 8,
                  children: PaymentMethod.values.map((m) {
                    final selected = _paymentMethod == m;
                    return ChoiceChip(
                      label: Text(_paymentLabel(m)),
                      selected: selected,
                      onSelected: (_) => setState(() => _paymentMethod = m),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _field(_notesController, 'Notes (optional)', Icons.notes_outlined, maxLines: 2),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _paymentLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.card => 'Card',
        PaymentMethod.bankTransfer => 'Bank',
      };

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(label, icon),
      validator: validator,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );
}
