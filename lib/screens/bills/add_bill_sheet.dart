import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/models/bill_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/providers/bill_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/widgets/receipt_picker.dart';

void showAddBillSheet(BuildContext context, {required String roomId, DateTime? initialDate}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
  final _amountController = TextEditingController();
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
    setState(() => _isLoading = true);

    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    List<String> splitAmong = room.memberIds;

    final userId = ref.read(currentUserIdProvider);
    final bill = BillModel(
      id: '',
      type: _billType,
      amount: double.parse(_amountController.text.trim()),
      paidBy: userId,
      splitType: 'equal',
      splitAmong: splitAmong,
      month: DateFormat('yyyy-MM').format(_date),
      date: _date,
      receiptUrl: _receiptUrl,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(billServiceProvider).addBill(widget.roomId, bill);
      
      // Log activity
      await ref.read(activityServiceProvider).log(
        roomId: widget.roomId,
        type: ActivityType.billAdded,
        performedBy: userId,
        description: 'Added ${bill.typeName} bill: ₹${bill.amount}',
        metadata: {
          'title': bill.type.name,
          'amount': bill.amount,
          'category': bill.type.name,
          'paidBy': bill.paidBy,
          'splitAmong': splitAmong,
          'date': DateFormat('dd MMM yyyy').format(bill.date),
          'type': bill.type.name
        },
      );

      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Add Bill', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Bill type
              SegmentedButton<BillType>(
                segments: const [
                  ButtonSegment(value: BillType.rent, label: Text('Rent'), icon: Icon(Icons.home, size: 18)),
                  ButtonSegment(value: BillType.electricity, label: Text('EB'), icon: Icon(Icons.bolt, size: 18)),
                  ButtonSegment(value: BillType.water, label: Text('Water'), icon: Icon(Icons.water_drop, size: 18)),
                ],
                selected: {_billType},
                onSelectionChanged: (v) => setState(() => _billType = v.first),
                style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
              const SizedBox(height: 18),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Date
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
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd MMM yyyy').format(_date)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Receipt
              ReceiptPicker(roomId: widget.roomId, folder: 'bills', onUploaded: (url) => _receiptUrl = url),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
