import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/bill_model.dart';
import 'package:split_ex/providers/bill_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/widgets/receipt_picker.dart';

class AddBillScreen extends ConsumerStatefulWidget {
  final String roomId;
  const AddBillScreen({super.key, required this.roomId});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  BillType _billType = BillType.rent;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  String? _receiptUrl;

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

    final userId = ref.read(currentUserIdProvider);
    final bill = BillModel(
      id: '',
      type: _billType,
      amount: double.parse(_amountController.text.trim()),
      paidBy: userId,
      month: DateFormat('yyyy-MM').format(_date),
      date: _date,
      receiptUrl: _receiptUrl,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(billServiceProvider).addBill(widget.roomId, bill);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bill')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bill Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<BillType>(
                segments: const [
                  ButtonSegment(
                    value: BillType.rent,
                    label: Text('Rent'),
                    icon: Icon(Icons.home),
                  ),
                  ButtonSegment(
                    value: BillType.electricity,
                    label: Text('EB'),
                    icon: Icon(Icons.bolt),
                  ),
                  ButtonSegment(
                    value: BillType.water,
                    label: Text('Water'),
                    icon: Icon(Icons.water_drop),
                  ),
                ],
                selected: {_billType},
                onSelectionChanged: (v) => setState(() => _billType = v.first),
              ),
              const SizedBox(height: 24),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('dd MMM yyyy').format(_date)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 16),
              // Receipt upload
              ReceiptPicker(
                roomId: widget.roomId,
                folder: 'bills',
                onUploaded: (url) => _receiptUrl = url,
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
                    : const Text('Add Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
