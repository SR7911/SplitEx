import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/group_expense_model.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

const _groupCategories = [
  'Food', 'Transport', 'Hotel', 'Tickets', 'Shopping',
  'Fuel', 'Activities', 'Groceries', 'Utilities', 'Other',
];

const _categoryIcons = <String, IconData>{
  'Food': Icons.restaurant,
  'Transport': Icons.directions_car,
  'Hotel': Icons.hotel,
  'Tickets': Icons.confirmation_number,
  'Shopping': Icons.shopping_bag,
  'Fuel': Icons.local_gas_station,
  'Activities': Icons.sports_soccer,
  'Groceries': Icons.shopping_cart,
  'Utilities': Icons.bolt,
  'Other': Icons.receipt_long,
};

// ─── Public entry points ──────────────────────────────────────────────────────

void showGroupExpenseSheet(
  BuildContext context, {
  required String groupId,
  required List<String> memberIds,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupExpenseSheet(
      groupId: groupId,
      memberIds: memberIds,
      expense: null,
    ),
  );
}

void showViewGroupExpenseSheet(
  BuildContext context, {
  required String groupId,
  required List<String> memberIds,
  required GroupExpenseModel expense,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupExpenseSheet(
      groupId: groupId,
      memberIds: memberIds,
      expense: expense,
    ),
  );
}

void showEditGroupExpenseSheet(
  BuildContext context, {
  required String groupId,
  required List<String> memberIds,
  required GroupExpenseModel expense,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupExpenseSheet(
      groupId: groupId,
      memberIds: memberIds,
      expense: expense,
      startInEditMode: true,
    ),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _GroupExpenseSheet extends ConsumerStatefulWidget {
  final String groupId;
  final List<String> memberIds;
  final GroupExpenseModel? expense;
  final bool startInEditMode;

  const _GroupExpenseSheet({
    required this.groupId,
    required this.memberIds,
    required this.expense,
    this.startInEditMode = false,
  });

  @override
  ConsumerState<_GroupExpenseSheet> createState() => _GroupExpenseSheetState();
}

class _GroupExpenseSheetState extends ConsumerState<_GroupExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _category;
  late DateTime _date;
  late GroupSplitType _splitType;
  late List<String> _selectedMembers;
  late String _paidBy;
  bool _editing = false;
  bool _isLoading = false;

  bool get _isAdd => widget.expense == null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? _groupCategories.first;
    _date = e?.date ?? DateTime.now();
    _splitType = e?.splitType ?? GroupSplitType.equal;
    _selectedMembers = e != null ? List<String>.from(e.splitAmong) : [];
    _paidBy = e?.paidBy ?? '';
    if (_isAdd || widget.startInEditMode) _editing = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _canEdit(String uid) =>
      widget.expense == null ||
      widget.expense!.createdBy == uid ||
      widget.expense!.paidBy == uid;

  void _cancelEdit() {
    final e = widget.expense!;
    setState(() {
      _editing = false;
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(0);
      _notesController.text = e.notes ?? '';
      _category = e.category;
      _date = e.date;
      _splitType = e.splitType;
      _selectedMembers = List<String>.from(e.splitAmong);
      _paidBy = e.paidBy;
    });
  }

  List<String> _resolveSplitAmong(String uid) {
    if (_splitType == GroupSplitType.equal) return widget.memberIds;
    return _selectedMembers.isEmpty ? [uid] : _selectedMembers;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    final paidBy = _paidBy.isEmpty ? uid : _paidBy;
    final splitAmong = _resolveSplitAmong(uid);
    final amount = double.parse(_amountController.text.trim());

    setState(() => _isLoading = true);
    try {
      if (_isAdd) {
        final expense = GroupExpenseModel(
          id: '',
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          amount: amount,
          category: _category,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          paidBy: paidBy,
          splitType: _splitType,
          splitAmong: splitAmong,
          date: _date,
          createdBy: uid,
          createdAt: DateTime.now(),
        );
        await ref.read(groupExpenseServiceProvider).addExpense(expense);
      } else {
        await ref.read(groupExpenseServiceProvider).updateExpense(
          widget.groupId,
          widget.expense!.id,
          {
            'title': _titleController.text.trim(),
            'amount': amount,
            'category': _category,
            'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            'paidBy': paidBy,
            'splitType': _splitType.name,
            'splitAmong': splitAmong,
            'date': Timestamp.fromDate(_date),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
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
        content: const Text('This cannot be undone.'),
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
      await ref.read(groupExpenseServiceProvider).deleteExpense(widget.groupId, widget.expense!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(roomMembersProvider(widget.memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }
    if (_paidBy.isEmpty) _paidBy = uid;

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
                _DragHandle(),
                _SheetHeader(
                  isAdd: _isAdd,
                  editing: _editing,
                  canEdit: _canEdit(uid),
                  onEdit: () => setState(() => _editing = true),
                  onCancel: _cancelEdit,
                  onDelete: _isAdd ? null : _delete,
                ),
                const SizedBox(height: 20),
                _TitleField(controller: _titleController, enabled: _editing),
                const SizedBox(height: 14),
                _AmountField(controller: _amountController, enabled: _editing),
                const SizedBox(height: 14),
                _CategoryDateRow(
                  category: _category,
                  date: _date,
                  enabled: _editing,
                  onCategoryChanged: (v) => setState(() => _category = v),
                  onDateChanged: (v) => setState(() => _date = v),
                ),
                const SizedBox(height: 14),
                _NotesField(controller: _notesController, enabled: _editing),
                const SizedBox(height: 14),
                _PaidBySelector(
                  memberIds: widget.memberIds,
                  nameMap: nameMap,
                  paidBy: _paidBy,
                  enabled: _editing,
                  onChanged: (v) => setState(() => _paidBy = v),
                ),
                const SizedBox(height: 16),
                _SplitSection(
                  splitType: _splitType,
                  selectedMembers: _selectedMembers,
                  memberIds: widget.memberIds,
                  nameMap: nameMap,
                  enabled: _editing,
                  onSplitTypeChanged: (v) => setState(() {
                    _splitType = v;
                    _selectedMembers = [];
                  }),
                  onMembersChanged: (v) => setState(() => _selectedMembers = v),
                ),
                // Per-person breakdown (view mode only)
                if (!_editing && widget.expense != null) ...[
                  const SizedBox(height: 16),
                  _ShareBreakdown(expense: widget.expense!, nameMap: nameMap),
                ],
                if (_editing) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isAdd ? 'Add Expense' : 'Save Changes',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48, height: 5,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final bool isAdd;
  final bool editing;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  const _SheetHeader({
    required this.isAdd,
    required this.editing,
    required this.canEdit,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(isAdd ? Icons.add_circle_outline : Icons.receipt_long, size: 22, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isAdd ? 'Add Group Expense' : 'Expense Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
          ),
        ),
        if (!isAdd && !editing && canEdit)
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: onEdit),
        if (!isAdd && !editing && onDelete != null)
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete', onPressed: onDelete),
        if (!isAdd && editing)
          IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: onCancel),
      ],
    );
  }
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _TitleField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: _dec(context, 'Title', Icons.receipt_long),
      validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
      textInputAction: TextInputAction.next,
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _AmountField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: _dec(context, 'Amount (₹)', Icons.currency_rupee),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter amount';
        if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
        return null;
      },
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _NotesField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: 2,
      decoration: _dec(context, 'Notes (optional)', Icons.notes),
    );
  }
}

class _CategoryDateRow extends StatelessWidget {
  final String category;
  final DateTime date;
  final bool enabled;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<DateTime> onDateChanged;

  const _CategoryDateRow({
    required this.category,
    required this.date,
    required this.enabled,
    required this.onCategoryChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: category,
            decoration: _dec(context, 'Category', Icons.category),
            items: _groupCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: enabled ? (v) => onCategoryChanged(v!) : null,
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) onDateChanged(picked);
                }
              : null,
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
                Icon(Icons.calendar_today, size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(enabled ? 0.6 : 0.4)),
                const SizedBox(width: 6),
                Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaidBySelector extends StatelessWidget {
  final List<String> memberIds;
  final Map<String, String> nameMap;
  final String paidBy;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PaidBySelector({
    required this.memberIds,
    required this.nameMap,
    required this.paidBy,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validPaidBy = memberIds.contains(paidBy) ? paidBy : memberIds.first;
    return DropdownButtonFormField<String>(
      value: validPaidBy,
      decoration: _dec(context, 'Paid by', Icons.person_outline),
      items: memberIds
          .map((id) => DropdownMenuItem(value: id, child: Text(nameMap[id] ?? id)))
          .toList(),
      onChanged: enabled ? (v) => onChanged(v!) : null,
      isExpanded: true,
    );
  }
}

class _SplitSection extends StatelessWidget {
  final GroupSplitType splitType;
  final List<String> selectedMembers;
  final List<String> memberIds;
  final Map<String, String> nameMap;
  final bool enabled;
  final ValueChanged<GroupSplitType> onSplitTypeChanged;
  final ValueChanged<List<String>> onMembersChanged;

  const _SplitSection({
    required this.splitType,
    required this.selectedMembers,
    required this.memberIds,
    required this.nameMap,
    required this.enabled,
    required this.onSplitTypeChanged,
    required this.onMembersChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.splitscreen_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text('Split', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<GroupSplitType>(
            segments: const [
              ButtonSegment(value: GroupSplitType.equal, label: Text('Equal')),
              ButtonSegment(value: GroupSplitType.selected, label: Text('Select')),
            ],
            selected: {splitType},
            onSelectionChanged: enabled ? (v) => onSplitTypeChanged(v.first) : null,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primary;
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return Theme.of(context).colorScheme.onSurface;
              }),
            ),
          ),
        ),
        if (splitType == GroupSplitType.selected) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: memberIds.map((id) {
              final selected = selectedMembers.contains(id);
              return FilterChip(
                label: Text(nameMap[id] ?? id),
                selected: selected,
                onSelected: enabled
                    ? (v) {
                        final updated = List<String>.from(selectedMembers);
                        if (v) updated.add(id); else updated.remove(id);
                        onMembersChanged(updated);
                      }
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              );
            }).toList(),
          ),
        ],
        if (!enabled && splitType == GroupSplitType.equal)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Split equally among ${memberIds.length} members',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
      ],
    );
  }
}

class _ShareBreakdown extends StatelessWidget {
  final GroupExpenseModel expense;
  final Map<String, String> nameMap;
  const _ShareBreakdown({required this.expense, required this.nameMap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_outlined, size: 16, color: primary),
              const SizedBox(width: 6),
              Text('Per person share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primary)),
            ],
          ),
          const SizedBox(height: 10),
          ...expense.splitAmong.map((uid) {
            final share = expense.shareFor(uid);
            final name = nameMap[uid] ?? uid;
            final isPayer = uid == expense.paidBy;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: primary.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPayer ? '$name (paid)' : name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isPayer ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '₹${share.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isPayer ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
