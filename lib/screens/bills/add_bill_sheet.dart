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

    final List<String> splitAmong = room.memberIds;
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
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Add Bill',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bill type (full‑width segmented)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Bill type',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<BillType>(
                        segments: const [
                          ButtonSegment(value: BillType.rent, label: Text('Rent'), icon: Icon(Icons.home, size: 18)),
                          ButtonSegment(value: BillType.electricity, label: Text('EB'), icon: Icon(Icons.bolt, size: 18)),
                          ButtonSegment(value: BillType.water, label: Text('Water'), icon: Icon(Icons.water_drop, size: 18)),
                        ],
                        selected: {_billType},
                        onSelectionChanged: (v) => setState(() => _billType = v.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) return Theme.of(context).colorScheme.primary;
                            return Colors.transparent;
                          }),
                          foregroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) return Colors.white;
                            return Colors.black87;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    labelStyle: const TextStyle(fontWeight: FontWeight.normal),
                    prefixIcon: Icon(Icons.currency_rupee, color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date picker
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(_date),
                          style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt picker
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ReceiptPicker(
                    roomId: widget.roomId,
                    folder: 'bills',
                    onUploaded: (url) => _receiptUrl = url,
                  ),
                ),
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
                      : const Text('Add Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}