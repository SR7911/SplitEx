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

void showAddExpenseSheet(BuildContext context, {required String roomId, DateTime? initialDate}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Add Expense',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: const TextStyle(fontWeight: FontWeight.normal),
                    prefixIcon: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    hintText: 'e.g. Groceries, Electricity',
                    hintStyle: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Amount field
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    labelStyle: const TextStyle(fontWeight: FontWeight.normal),
                    prefixIcon: Icon(Icons.currency_rupee, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                const SizedBox(height: 16),

                // Category & Date row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(fontWeight: FontWeight.normal),
                          prefixIcon: Icon(Icons.category, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            Text(
                              DateFormat('dd MMM yyyy').format(_date),
                              style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Receipt picker
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ReceiptPicker(
                    roomId: widget.roomId,
                    folder: 'expenses',
                    onUploaded: (url) => _receiptUrl = url,
                  ),
                ),
                const SizedBox(height: 16),

                // Split method section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.splitscreen_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Text(
                            'Split method',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<SplitType>(
                          segments: const [
                            ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                            ButtonSegment(value: SplitType.dynamic, label: Text('Custom')),
                            ButtonSegment(value: SplitType.oneToOne, label: Text('1-to-1')),
                          ],
                          selected: {_splitType},
                          onSelectionChanged: (v) => setState(() { _splitType = v.first; _selectedMembers = [];}),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    ],
                  ),
                ),

                // Member selection (if not equal)
                if (_splitType != SplitType.equal && room != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                            const SizedBox(width: 8),
                            Text(
                              _splitType == SplitType.oneToOne
                                  ? 'Who owes the full amount?'
                                  : 'Share with:',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._buildMemberChips(room.memberIds),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Save button
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
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: others.map((memberId) {
          final selected = _selectedMembers.contains(memberId);
          return FilterChip(
            label: Text(
              nameMap[memberId] ?? memberId,
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                fontFamily: 'Gilmer', // enforce Gilmer
              ),
            ),
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
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            checkmarkColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          );
        }).toList(),
      ),
    ];
  }
}