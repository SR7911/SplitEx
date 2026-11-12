import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/dependencies.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/modules/room/presentation/widgets/receipt_picker.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/expense/add_expense_sheet.dart'
    show RoomDateButton;
import 'package:split_ex/shared/ui/design_system/design_system.dart';

void showAddBillSheet(
  BuildContext context, {
  required String roomId,
  DateTime? initialDate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddBillSheet(roomId: roomId, initialDate: initialDate),
  );
}

class _AddBillSheet extends ConsumerStatefulWidget {
  final String roomId;
  final DateTime? initialDate;
  const _AddBillSheet({required this.roomId, this.initialDate});

  @override
  ConsumerState<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends ConsumerState<_AddBillSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  BillType _billType = BillType.rent;
  late DateTime _date;
  bool _isLoading = false;
  String? _receiptUrl;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
    if (room == null) return;
    final userId = ref.read(currentUserIdProvider);
    if (!room.canWrite(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This room is read-only for you.')));
      return;
    }
    setState(() => _isLoading = true);
    final bill = BillModel(
      id: '',
      type: _billType,
      amount: double.parse(_amountCtrl.text.trim()),
      paidBy: userId,
      splitType: 'equal',
      splitAmong: room.memberIds,
      month: DateFormat('yyyy-MM').format(_date),
      date: _date,
      receiptUrl: _receiptUrl,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(recordRoomBillProvider)(widget.roomId, bill);
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PersonalFormSheet(
      title: 'Add Bill',
      icon: Icons.receipt_long_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bill type
            Text(
              'Bill Type',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
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

            // Amount
            TextFormField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0)
                  return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Date
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
            const SizedBox(height: AppSpacing.md),

            // Receipt
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: ReceiptPicker(
                roomId: widget.roomId,
                folder: 'bills',
                onUploaded: (url) => _receiptUrl = url,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Bill'),
            ),
          ],
        ),
      ),
    );
  }
}
