import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/room_bill_update.dart';
import 'package:split_ex/modules/room/presentation/providers/bill_provider.dart';
import 'package:split_ex/modules/room/dependencies.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/expense/add_expense_sheet.dart'
    show RoomDateButton;
import 'package:split_ex/modules/room/presentation/screens/expense/view_expense_sheet.dart'
    show RoomViewRow;
import 'package:split_ex/shared/ui/design_system/design_system.dart';

void showViewBillSheet(
  BuildContext context, {
  required String roomId,
  required BillModel bill,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ViewBillSheet(roomId: roomId, bill: bill),
  );
}

class _ViewBillSheet extends ConsumerStatefulWidget {
  final String roomId;
  final BillModel bill;
  const _ViewBillSheet({required this.roomId, required this.bill});

  @override
  ConsumerState<_ViewBillSheet> createState() => _ViewBillSheetState();
}

class _ViewBillSheetState extends ConsumerState<_ViewBillSheet> {
  bool _editing = false;
  bool _isLoading = false;
  late TextEditingController _amountCtrl;
  late BillType _billType;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.bill.amount.toStringAsFixed(2));
    _billType = widget.bill.type;
    _date = widget.bill.date;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final userId = ref.read(currentUserIdProvider);
    final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
    return (room?.canWrite(userId) ?? false) &&
        (widget.bill.paidBy == userId || (room?.isAdmin(userId) ?? false));
  }

  void _cancelEdit() => setState(() {
        _editing = false;
        _amountCtrl.text = widget.bill.amount.toStringAsFixed(0);
        _billType = widget.bill.type;
        _date = widget.bill.date;
      });

  Future<void> _save() async {
    if (!_canEdit) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(billServiceProvider).updateBill(
            widget.roomId,
            widget.bill.id,
            RoomBillUpdate(
              type: _billType,
              amount: amount,
              date: _date,
              month: DateFormat('yyyy-MM').format(_date),
            ),
            performedBy: ref.read(currentUserIdProvider),
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
        title: const Text('Delete Bill?'),
        content: Text(
            'Delete ${widget.bill.type.name} bill for ₹${widget.bill.amount.toStringAsFixed(0)}?'),
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
      await ref.read(deleteRoomBillProvider)(
          widget.roomId, widget.bill, userId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReceipt(String path) {
    final isLocal = !path.startsWith('http');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
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
                          child: Text('Failed to load')))
                  : Image.network(path, fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Failed to load'))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = {
      ...?ref
          .watch(roomStreamProvider(widget.roomId))
          .valueOrNull
          ?.historicalMemberIds,
      ...widget.bill.splitAmong,
      widget.bill.paidBy,
    }.toList();
    final membersAsync = ref.watch(userProfilesByIdsProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }
    final paidByName = nameMap[widget.bill.paidBy] ?? widget.bill.paidBy;
    final billIcon = switch (widget.bill.type) {
      BillType.rent => Icons.home_rounded,
      BillType.electricity => Icons.bolt_rounded,
      BillType.water => Icons.water_drop_rounded,
    };

    if (_editing) return _buildEditMode(context);

    // ── VIEW MODE ──
    return PersonalFormSheet(
      title: 'Bill Details',
      icon: billIcon,
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
                icon: billIcon,
                label: 'Type',
                value: widget.bill.type.name[0].toUpperCase() +
                    widget.bill.type.name.substring(1),
              ),
              RoomViewRow(
                icon: Icons.currency_rupee_rounded,
                label: 'Amount',
                value: '₹${widget.bill.amount.toStringAsFixed(2)}',
                valueColor: AppColors.error(context),
              ),
              RoomViewRow(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: DateFormat('dd MMM yyyy').format(widget.bill.date),
              ),
              RoomViewRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Paid by',
                  value: paidByName),
              RoomViewRow(
                  icon: Icons.date_range_rounded,
                  label: 'Month',
                  value: widget.bill.month),
            ]),
          ),
          if (widget.bill.receiptUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: () => _showReceipt(widget.bill.receiptUrl!),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('View Receipt'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditMode(BuildContext context) {
    return PersonalFormSheet(
      title: 'Edit Bill',
      icon: Icons.edit_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bill Type',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<BillType>(
            segments: const [
              ButtonSegment(
                  value: BillType.rent,
                  label: Text('Rent'),
                  icon: Icon(Icons.home_rounded, size: 16)),
              ButtonSegment(
                  value: BillType.electricity,
                  label: Text('EB'),
                  icon: Icon(Icons.bolt_rounded, size: 16)),
              ButtonSegment(
                  value: BillType.water,
                  label: Text('Water'),
                  icon: Icon(Icons.water_drop_rounded, size: 16)),
            ],
            selected: {_billType},
            onSelectionChanged: (v) =>
                setState(() => _billType = v.first),
          ),
          const SizedBox(height: AppSpacing.base),
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
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: _cancelEdit, child: const Text('Cancel')),
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
