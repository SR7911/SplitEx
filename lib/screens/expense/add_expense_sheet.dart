import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/config/constants.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/widgets/receipt_picker.dart';

/// Shows the add expense bottom sheet. Call this instead of navigating.
void showAddExpenseSheet(BuildContext context, {required String roomId, DateTime? initialDate}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddExpenseSheet(roomId: roomId, initialDate: initialDate),
  );
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String roomId;
  final DateTime? initialDate;
  const _AddExpenseSheet({required this.roomId, this.initialDate});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = AppConstants.expenseCategories.first;
  late DateTime _date;
  SplitType _splitType = SplitType.equal;
  List<String> _selectedMembers = [];
  bool _isLoading = false;
  String? _receiptUrl;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final userId = ref.read(currentUserIdProvider);
    List<String> splitAmong;

    switch (_splitType) {
      case SplitType.equal:
        splitAmong = room.memberIds;
        break;
      case SplitType.dynamic:
        if (_selectedMembers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one member')),
          );
          return;
        }
        splitAmong = _selectedMembers;
        break;
      case SplitType.oneToOne:
        if (_selectedMembers.length != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select exactly one person')),
          );
          return;
        }
        // For one-to-one split, the selected person owes the full amount to the payer.
        splitAmong = [_selectedMembers.first];
        break;
    }

    setState(() => _isLoading = true);
    try {
      final expense = ExpenseModel(
        id: '',
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _category,
        date: _date,
        paidBy: userId,
        splitType: _splitType,
        splitAmong: splitAmong,
        createdBy: userId,
        createdAt: DateTime.now(),
        month: DateFormat('yyyy-MM').format(_date),
        receiptUrl: _receiptUrl,
      );

      await ref.read(expenseServiceProvider).addExpense(widget.roomId, expense);
      ref.read(activityServiceProvider).log(
        roomId: widget.roomId,
        type: ActivityType.expenseAdded,
        performedBy: userId,
        description: 'Added "${expense.title}" for ₹${expense.amount.toStringAsFixed(0)}',
        metadata: {
          'title': expense.title,
          'amount': expense.amount,
          'category': expense.category,
          'paidBy': expense.paidBy,
          'splitAmong': expense.splitAmong,
          'date': DateFormat('dd MMM yyyy').format(expense.date),
        },
      );
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Text('Add Expense',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.receipt_long),
                  hintText: 'e.g. Groceries, Electricity',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) {
                    return 'Enter valid amount';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 14),

              // Category & Date row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: AppConstants.expenseCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd MMM').format(_date), style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Receipt attachment
              ReceiptPicker(
                roomId: widget.roomId,
                folder: 'expenses',
                onUploaded: (url) => _receiptUrl = url,
              ),
              const SizedBox(height: 18),

              // Split type
              Text('Split', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                  ButtonSegment(value: SplitType.dynamic, label: Text('Custom')),
                  ButtonSegment(value: SplitType.oneToOne, label: Text('1-to-1')),
                ],
                selected: {_splitType},
                onSelectionChanged: (v) => setState(() => _splitType = v.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Member selection
              if (_splitType != SplitType.equal && room != null) ...[
                const SizedBox(height: 12),
                Text(
                  _splitType == SplitType.oneToOne
                      ? 'Select one person who owes the full amount:'
                      : 'Split with:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ..._buildMemberChips(room.memberIds),
              ],
              const SizedBox(height: 24),

              // Save button
              FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMemberChips(List<String> memberIds) {
    final userId = ref.read(currentUserIdProvider);
    final membersAsync = ref.watch(roomMembersProvider(memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }

    final others = memberIds.where((id) => id != userId).toList();

    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: others.map((memberId) {
          final selected = _selectedMembers.contains(memberId);
          return FilterChip(
            label: Text(nameMap[memberId] ?? memberId),
            selected: selected,
            onSelected: (checked) {
              setState(() {
                if (_splitType == SplitType.oneToOne) {
                  _selectedMembers = checked ? [memberId] : [];
                } else {
                  if (checked) {
                    _selectedMembers.addAll([memberId, userId]);
                    _selectedMembers = _selectedMembers.toSet().toList();
                  } else {
                    _selectedMembers = _selectedMembers
                      .where((id) => id != memberId && id != userId)
                      .toList();
                  }
                }
              });
            },
          );
        }).toList(),
      ),
    ];
  }
}
