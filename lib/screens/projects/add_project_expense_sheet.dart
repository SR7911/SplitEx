import 'package:cloud_firestore/cloud_firestore.dart';
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

// ─── Public entry points ──────────────────────────────────────────────────────

void showAddProjectExpenseSheet(BuildContext context, {required String projectId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProjectExpenseSheet(projectId: projectId, expense: null),
  );
}

void showViewProjectExpenseSheet(BuildContext context, {required String projectId, required ProjectExpenseModel expense}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProjectExpenseSheet(projectId: projectId, expense: expense),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _ProjectExpenseSheet extends ConsumerStatefulWidget {
  final String projectId;
  final ProjectExpenseModel? expense;
  const _ProjectExpenseSheet({required this.projectId, required this.expense});

  @override
  ConsumerState<_ProjectExpenseSheet> createState() => _ProjectExpenseSheetState();
}

class _ProjectExpenseSheetState extends ConsumerState<_ProjectExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _vendorController;
  late final TextEditingController _notesController;
  late final TextEditingController _personController;
  late String _category;
  late PaymentMethod _paymentMethod;
  late DateTime _date;
  ProjectDebtType? _debtType;
  bool _editing = false;
  bool _isLoading = false;
  bool _settling = false;

  bool get _isAdd => widget.expense == null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _vendorController = TextEditingController(text: e?.vendor ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _personController = TextEditingController(text: e?.personName ?? '');
    _category = e?.category ?? _projectCategories.first;
    _paymentMethod = e?.paymentMethod ?? PaymentMethod.cash;
    _date = e?.date ?? DateTime.now();
    _debtType = e?.debtType;
    if (_isAdd) _editing = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    _personController.dispose();
    super.dispose();
  }

  void _cancelEdit() {
    final e = widget.expense!;
    setState(() {
      _editing = false;
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(0);
      _vendorController.text = e.vendor ?? '';
      _notesController.text = e.notes ?? '';
      _personController.text = e.personName ?? '';
      _category = e.category;
      _paymentMethod = e.paymentMethod;
      _date = e.date;
      _debtType = e.debtType;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_debtType != null && _personController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter person name for debt')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      final svc = ref.read(projectExpenseServiceProvider);
      if (_isAdd) {
        await svc.addExpense(uid, ProjectExpenseModel(
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
          debtType: _debtType,
          personName: _debtType != null ? _personController.text.trim() : null,
        ));
      } else {
        await svc.updateExpense(uid, widget.projectId, widget.expense!.id, {
          'title': _titleController.text.trim(),
          'amount': double.parse(_amountController.text.trim()),
          'category': _category,
          'vendor': _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim(),
          'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          'paymentMethod': _paymentMethod.name,
          'date': Timestamp.fromDate(_date),
          'debtType': _debtType?.name,
          'personName': _debtType != null ? _personController.text.trim() : null,
          'isSettled': widget.expense!.isSettled,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${widget.expense!.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final uid = ref.read(currentUserIdProvider);
      await ref.read(projectExpenseServiceProvider).deleteExpense(uid, widget.projectId, widget.expense!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _settle() async {
    setState(() => _settling = true);
    final uid = ref.read(currentUserIdProvider);
    await ref.read(projectExpenseServiceProvider).updateExpense(uid, widget.projectId, widget.expense!.id, {'isSettled': true});
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as settled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_isAdd ? Icons.add_circle_outline : Icons.receipt_long, size: 22, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isAdd ? 'Add Expense' : 'Expense Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
                      ),
                    ),
                    if (!_isAdd && !_editing) ...[
                      IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => setState(() => _editing = true)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete', onPressed: _delete),
                    ],
                    if (!_isAdd && _editing)
                      IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: _cancelEdit),
                  ],
                ),
                const SizedBox(height: 20),

                if (_editing) ...[
                  // ── Edit / Add form ──
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
                          decoration: _dec(context, 'Category', Icons.category),
                          items: _projectCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _category = v!),
                          isExpanded: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () async {
                          final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Debt Tracking (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _DebtChip(label: 'None', selected: _debtType == null, color: Colors.grey, onTap: () => setState(() => _debtType = null)),
                            const SizedBox(width: 8),
                            _DebtChip(label: 'I Lent', selected: _debtType == ProjectDebtType.lent, color: Colors.green, onTap: () => setState(() => _debtType = ProjectDebtType.lent)),
                            const SizedBox(width: 8),
                            _DebtChip(label: 'I Borrowed', selected: _debtType == ProjectDebtType.borrowed, color: Colors.red, onTap: () => setState(() => _debtType = ProjectDebtType.borrowed)),
                          ],
                        ),
                        if (_debtType != null) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _personController,
                            decoration: InputDecoration(
                              labelText: 'Person Name',
                              prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isAdd ? 'Add Expense' : 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ] else ...[
                  // ── View mode ──
                  _ViewDetails(expense: widget.expense!),
                  if (widget.expense!.hasDebt && !widget.expense!.isSettled) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _settling ? null : _settle,
                      icon: _settling
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(widget.expense!.debtType?.name == 'lent' ? 'Mark as Received' : 'Mark as Repaid'),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.expense!.debtType?.name == 'lent' ? Colors.green : Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ],
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

  Widget _field(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(context, label, icon),
      validator: validator,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    );
  }
}

// ─── View Details ─────────────────────────────────────────────────────────────

class _ViewDetails extends StatelessWidget {
  final ProjectExpenseModel expense;
  const _ViewDetails({required this.expense});

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final debtColor = e.debtType?.name == 'lent' ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? primary.withOpacity(0.08) : primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          _DetailRow(icon: Icons.receipt_long, label: 'Title', value: e.title),
          _DetailRow(icon: Icons.currency_rupee, label: 'Amount', value: '₹${e.amount.toStringAsFixed(0)}', valueColor: primary),
          _DetailRow(icon: Icons.category, label: 'Category', value: e.category),
          _DetailRow(icon: Icons.calendar_today, label: 'Date', value: DateFormat('dd MMM yyyy').format(e.date)),
          _DetailRow(icon: Icons.payment, label: 'Payment', value: e.paymentMethod.name),
          if (e.vendor != null) _DetailRow(icon: Icons.store_outlined, label: 'Vendor', value: e.vendor!),
          if (e.hasDebt) ...[
            _DetailRow(
              icon: e.debtType?.name == 'lent' ? Icons.call_made : Icons.call_received,
              label: 'Debt',
              value: e.debtType?.name == 'lent' ? 'You Lent' : 'You Borrowed',
              valueColor: debtColor,
            ),
            if (e.personName != null) _DetailRow(icon: Icons.person, label: 'Person', value: e.personName!),
            _DetailRow(icon: Icons.check_circle_outline, label: 'Settled', value: e.isSettled ? 'Yes' : 'No'),
          ],
          if (e.notes != null && e.notes!.isNotEmpty) _DetailRow(icon: Icons.notes, label: 'Notes', value: e.notes!),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

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

class _DebtChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _DebtChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? color : Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ),
    );
  }
}

InputDecoration _dec(BuildContext context, String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
