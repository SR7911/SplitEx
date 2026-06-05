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

class EditExpenseScreen extends ConsumerStatefulWidget {
  final String roomId;
  final ExpenseModel expense;

  const EditExpenseScreen({
    super.key,
    required this.roomId,
    required this.expense,
  });

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late String _category;
  late DateTime _date;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _amountController =
        TextEditingController(text: widget.expense.amount.toStringAsFixed(0));
    _category = widget.expense.category;
    _date = widget.expense.date;
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
    final userId = ref.read(currentUserIdProvider);
    setState(() => _isLoading = true);
    try {
      await ref.read(expenseServiceProvider).updateExpense(
        widget.roomId,
        widget.expense.id,
        {
          'title': _titleController.text.trim(),
          'amount': double.parse(_amountController.text.trim()),
          'category': _category,
          'date': _date,
        },
      );
      ref.read(activityServiceProvider).log(
        roomId: widget.roomId,
        type: ActivityType.expenseEdited,
        performedBy: userId,
        description: 'Edited "${_titleController.text.trim()}"',
        metadata: {
          'title': _titleController.text.trim(),
          'amount': double.parse(_amountController.text.trim()),
          'category': _category,
          'paidBy': widget.expense.paidBy,
          'splitAmong': widget.expense.splitAmong,
          'date': DateFormat('dd MMM yyyy').format(_date),
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

  @override
  Widget build(BuildContext context) {
    final userId = ref.read(currentUserIdProvider);
    final room = ref.watch(currentRoomProvider);
    final canEdit =
        widget.expense.createdBy == userId || (room?.isAdmin(userId) ?? false);

    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Expense')),
        body: const Center(child: Text('You cannot edit this expense')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Expense')),
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
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
