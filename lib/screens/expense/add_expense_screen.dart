import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/config/constants.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/widgets/receipt_picker.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String roomId;
  const AddExpenseScreen({super.key, required this.roomId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = AppConstants.expenseCategories.first;
  DateTime _date = DateTime.now();
  SplitType _splitType = SplitType.equal;
  List<String> _selectedMembers = [];
  bool _isLoading = false;
  String? _receiptUrl;

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
      if (mounted) context.pop();
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

  List<Widget> _buildMemberCheckboxes(List<String> memberIds) {
    final userId = ref.read(currentUserIdProvider);
    final membersAsync = ref.watch(roomMembersProvider(memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }

    return memberIds
        .where((id) => id != userId)
        .map((memberId) {
      return CheckboxListTile(
        title: Text(nameMap[memberId] ?? memberId),
        value: _selectedMembers.contains(memberId),
        onChanged: (checked) {
          setState(() {
            if (_splitType == SplitType.oneToOne) {
              _selectedMembers = checked == true ? [memberId] : [];
            } else {
              if (checked == true) {
                _selectedMembers.add(memberId);
              } else {
                _selectedMembers.remove(memberId);
              }
            }
          });
        },
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.receipt_long),
                  hintText: 'e.g. Groceries, Electricity bill',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),
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
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: AppConstants.expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('dd MMM yyyy').format(_date)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
              ),
              const Divider(height: 32),
              ReceiptPicker(
                roomId: widget.roomId,
                folder: 'expenses',
                onUploaded: (url) => _receiptUrl = url,
              ),
              const SizedBox(height: 16),
              Text('Split Type',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                  ButtonSegment(
                      value: SplitType.dynamic, label: Text('Dynamic')),
                  ButtonSegment(
                      value: SplitType.oneToOne, label: Text('1-to-1')),
                ],
                selected: {_splitType},
                onSelectionChanged: (v) =>
                    setState(() => _splitType = v.first),
              ),
              if (_splitType != SplitType.equal && room != null) ...[
                const SizedBox(height: 16),
                Text(
                  _splitType == SplitType.oneToOne
                      ? 'Select one person who owes the full amount:'
                      : 'Select members to split with:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ..._buildMemberCheckboxes(room.memberIds),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
