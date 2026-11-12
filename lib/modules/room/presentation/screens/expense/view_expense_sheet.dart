import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/dependencies.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/presentation/config/room_constants.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/policies/split_calculator.dart';
import 'package:split_ex/modules/room/domain/entities/room_expense_update.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/expense/add_expense_sheet.dart'
    show RoomDateButton, RoomMemberPicker;
import 'package:split_ex/shared/ui/design_system/design_system.dart';

void showViewExpenseSheet(
  BuildContext context, {
  required String roomId,
  required ExpenseModel expense,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ViewExpenseSheet(roomId: roomId, expense: expense),
  );
}

class _ViewExpenseSheet extends ConsumerStatefulWidget {
  final String roomId;
  final ExpenseModel expense;
  const _ViewExpenseSheet({required this.roomId, required this.expense});

  @override
  ConsumerState<_ViewExpenseSheet> createState() => _ViewExpenseSheetState();
}

class _ViewExpenseSheetState extends ConsumerState<_ViewExpenseSheet> {
  bool _editing = false;
  bool _isLoading = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late String _category;
  late DateTime _date;
  late SplitType _splitType;
  late List<String> _selectedMembers;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.expense.title);
    _amountCtrl = TextEditingController(
        text: widget.expense.amount.toStringAsFixed(2));
    _category = widget.expense.category;
    _date = widget.expense.date;
    _splitType = widget.expense.splitType;
    _selectedMembers = List<String>.from(widget.expense.splitAmong);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final userId = ref.read(currentUserIdProvider);
    final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
    return (room?.canWrite(userId) ?? false) &&
        (widget.expense.createdBy == userId ||
            (room?.isAdmin(userId) ?? false));
  }

  void _cancelEdit() => setState(() {
        _editing = false;
        _titleCtrl.text = widget.expense.title;
        _amountCtrl.text = widget.expense.amount.toStringAsFixed(0);
        _category = widget.expense.category;
        _date = widget.expense.date;
        _splitType = widget.expense.splitType;
        _selectedMembers = List<String>.from(widget.expense.splitAmong);
      });

  Future<void> _save() async {
    if (!_canEdit) return;
    if (_titleCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty)
      return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
    List<String> splitAmong;
    switch (_splitType) {
      case SplitType.equal:
        splitAmong = _splitType == widget.expense.splitType
            ? widget.expense.splitAmong
            : (room?.memberIds ?? widget.expense.splitAmong);
        break;
      case SplitType.dynamic:
        if (_selectedMembers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select at least one member')));
          return;
        }
        splitAmong = _selectedMembers;
        break;
      case SplitType.oneToOne:
        if (_selectedMembers.length != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select exactly one person')));
          return;
        }
        splitAmong = [_selectedMembers.first];
        break;
    }

    setState(() => _isLoading = true);
    final userId = ref.read(currentUserIdProvider);
    try {
      await ref.read(editRoomExpenseProvider)(
        widget.roomId,
        widget.expense,
        RoomExpenseUpdate(
          title: _titleCtrl.text.trim(),
          amount: amount,
          category: _category,
          date: _date,
          splitType: _splitType,
          splitAmong: splitAmong,
          month: DateFormat('yyyy-MM').format(_date),
        ),
        userId,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete Expense?'),
        content: Text('Delete "${widget.expense.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error(context)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    final userId = ref.read(currentUserIdProvider);
    try {
      await ref.read(deleteRoomExpenseProvider)(
          widget.roomId, widget.expense, userId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Dead code — receipt button removed from UI
  void _showReceipt(BuildContext context, String path) {
    final isLocal = !path.startsWith('http');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx))
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: isLocal
                  ? Image.file(File(path), fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Failed to load image')))
                  : Image.network(path, fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Failed to load image'))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomStreamProvider(widget.roomId)).valueOrNull;
    final members = {
      ...?room?.memberIds,
      ...widget.expense.splitAmong,
      widget.expense.paidBy,
    }.toList();
    final membersAsync = ref.watch(userProfilesByIdsProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }
    final paidByName =
        nameMap[widget.expense.paidBy] ?? widget.expense.paidBy;
    final splitNames =
        widget.expense.splitAmong.map((id) => nameMap[id] ?? id).join(', ');
    final icon = RoomConstants.categoryIcons[widget.expense.category] ??
        Icons.receipt_long_rounded;

    if (_editing) return _buildEditMode(context, room, members);

    // ── VIEW MODE ──
    return PersonalFormSheet(
      title: 'Expense Details',
      icon: icon,
      trailing: _canEdit
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: _delete,
                icon: Icon(Icons.delete_outline,
                    color: AppColors.error(context)),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ])
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: appCardDecoration(context),
            child: Column(children: [
              RoomViewRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Title',
                  value: widget.expense.title),
              RoomViewRow(
                icon: Icons.currency_rupee_rounded,
                label: 'Amount',
                value: '₹${widget.expense.amount.toStringAsFixed(2)}',
                valueColor: AppColors.error(context),
              ),
              RoomViewRow(
                  icon: Icons.label_outline_rounded,
                  label: 'Category',
                  value: widget.expense.category),
              RoomViewRow(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: DateFormat('dd MMM yyyy').format(widget.expense.date),
              ),
              RoomViewRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Paid by',
                  value: paidByName),
              RoomViewRow(
                  icon: Icons.call_split_rounded,
                  label: 'Split',
                  value: widget.expense.splitType.name),
              RoomViewRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Among',
                  value: splitNames),
              RoomViewRow(
                icon: Icons.calculate_outlined,
                label: 'Per person',
                value:
                    '₹${widget.expense.splitAmount.toStringAsFixed(2)}',
                valueColor: AppColors.info(context),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(BuildContext context, dynamic room, List<String> members) {
    final userId = ref.read(currentUserIdProvider);
    return PersonalFormSheet(
      title: 'Edit Expense',
      icon: Icons.edit_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: RoomConstants.expenseCategories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
                isExpanded: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            RoomDateButton(
              date: _date,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.base),
          Text('Split Method',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<SplitType>(
            segments: const [
              ButtonSegment(value: SplitType.equal, label: Text('Equal')),
              ButtonSegment(
                  value: SplitType.dynamic, label: Text('Custom')),
              ButtonSegment(
                  value: SplitType.oneToOne, label: Text('1-to-1')),
            ],
            selected: {_splitType},
            onSelectionChanged: (v) => setState(() {
              _splitType = v.first;
              _selectedMembers = [];
            }),
          ),
          if (_splitType != SplitType.equal && room != null) ...[
            const SizedBox(height: AppSpacing.md),
            RoomMemberPicker(
              memberIds: room.memberIds as List<String>,
              payerId: userId,
              splitType: _splitType,
              selected: _selectedMembers,
              onChanged: (v) => setState(() => _selectedMembers = v),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelEdit,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── _ViewRow ─────────────────────────────────────────────────────────────────

class RoomViewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const RoomViewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: .45)),
        const SizedBox(width: AppSpacing.md),
        Text(label,
            style: AppTextStyles.label(context)
                .copyWith(color: cs.onSurface.withValues(alpha: .6))),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: AppTextStyles.label(context).copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ]),
    );
  }
}
