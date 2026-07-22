import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/group_expense_model.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

const _groupCategories = [
  'Food', 'Transport', 'Hotel', 'Tickets', 'Shopping',
  'Fuel', 'Activities', 'Groceries', 'Other',
];

void showGroupExpenseSheet(BuildContext context, {required String groupId, required List<String> memberIds}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupExpenseSheet(groupId: groupId, memberIds: memberIds),
  );
}

class _GroupExpenseSheet extends ConsumerStatefulWidget {
  final String groupId;
  final List<String> memberIds;
  const _GroupExpenseSheet({required this.groupId, required this.memberIds});

  @override
  ConsumerState<_GroupExpenseSheet> createState() => _GroupExpenseSheetState();
}

class _GroupExpenseSheetState extends ConsumerState<_GroupExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = _groupCategories.first;
  DateTime _date = DateTime.now();
  GroupSplitType _splitType = GroupSplitType.equal;
  List<String> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);

    final splitAmong = _splitType == GroupSplitType.equal
        ? widget.memberIds
        : _selectedMembers.isEmpty
            ? [uid]
            : _selectedMembers;

    setState(() => _isLoading = true);
    try {
      final expense = GroupExpenseModel(
        id: '',
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _category,
        paidBy: uid,
        splitType: _splitType,
        splitAmong: splitAmong,
        date: _date,
        createdBy: uid,
        createdAt: DateTime.now(),
      );
      await ref.read(groupExpenseServiceProvider).addExpense(expense);
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
    final membersAsync = ref.watch(roomMembersProvider(widget.memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }

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
                    Text('Add Group Expense', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: _dec('Title', Icons.receipt_long),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Amount (₹)', Icons.currency_rupee),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: _dec('Category', Icons.category),
                        items: _groupCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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
                const SizedBox(height: 16),
                // Split type
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<GroupSplitType>(
                    segments: const [
                      ButtonSegment(value: GroupSplitType.equal, label: Text('Equal')),
                      ButtonSegment(value: GroupSplitType.selected, label: Text('Select')),
                    ],
                    selected: {_splitType},
                    onSelectionChanged: (v) => setState(() { _splitType = v.first; _selectedMembers = []; }),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) return Theme.of(context).colorScheme.primary;
                        return Colors.transparent;
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) return Colors.white;
                        return Theme.of(context).colorScheme.onSurface;
                      }),
                    ),
                  ),
                ),
                if (_splitType == GroupSplitType.selected) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.memberIds.map((id) {
                      final selected = _selectedMembers.contains(id);
                      return FilterChip(
                        label: Text(nameMap[id] ?? id),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) _selectedMembers.add(id);
                          else _selectedMembers.remove(id);
                        }),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      );
                    }).toList(),
                  ),
                ],
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

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );
}
