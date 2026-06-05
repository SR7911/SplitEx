import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/bill_model.dart';
import 'package:split_ex/providers/bill_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

void showViewBillSheet(BuildContext context, {required String roomId, required BillModel bill}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
  late TextEditingController _amountController;
  late BillType _billType;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.bill.amount.toStringAsFixed(0));
    _billType = widget.bill.type;
    _date = widget.bill.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final userId = ref.read(currentUserIdProvider);
    final room = ref.read(currentRoomProvider);
    return widget.bill.paidBy == userId || (room?.isAdmin(userId) ?? false);
  }

  Future<void> _pickDate() async {
    if (!_editing) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(billServiceProvider).updateBill(widget.roomId, widget.bill.id, {
        'type': _billType.name,
        'amount': amount,
        'date': _date,
        'month': DateFormat('yyyy-MM').format(_date),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _amountController.text = widget.bill.amount.toStringAsFixed(0);
      _billType = widget.bill.type;
      _date = widget.bill.date;
    });
  }

  void _showReceipt(String path) {
    final isLocal = !path.startsWith('http');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt'),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: isLocal
                  ? Image.file(File(path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(32), child: Text('Failed to load')))
                  : Image.network(path, fit: BoxFit.contain,
                      loadingBuilder: (_, child, p) => p == null ? child : const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(32), child: Text('Failed to load'))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(currentRoomProvider);
    final members = room?.memberIds ?? [];
    final membersAsync = ref.watch(roomMembersProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }
    final paidByName = nameMap[widget.bill.paidBy] ?? widget.bill.paidBy;
    final billIcon = switch (widget.bill.type) {
      BillType.rent => Icons.home,
      BillType.electricity => Icons.bolt,
      BillType.water => Icons.water_drop,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header
            Row(
              children: [
                CircleAvatar(child: Icon(billIcon, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Bill Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (_canEdit && !_editing)
                  IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => setState(() => _editing = true)),
                if (_editing)
                  IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: _cancelEdit),
              ],
            ),
            const Divider(height: 24),

            // Bill type
            SegmentedButton<BillType>(
              segments: const [
                ButtonSegment(value: BillType.rent, label: Text('Rent'), icon: Icon(Icons.home, size: 18)),
                ButtonSegment(value: BillType.electricity, label: Text('EB'), icon: Icon(Icons.bolt, size: 18)),
                ButtonSegment(value: BillType.water, label: Text('Water'), icon: Icon(Icons.water_drop, size: 18)),
              ],
              selected: {_billType},
              onSelectionChanged: _editing ? (v) => setState(() => _billType = v.first) : null,
              style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            const SizedBox(height: 14),

            // Amount
            TextFormField(
              controller: _amountController,
              enabled: _editing,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)', prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 14),

            // Date
            InkWell(
              onTap: _editing ? _pickDate : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: _editing ? Colors.grey.shade300 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: _editing ? null : Colors.grey),
                    const SizedBox(width: 10),
                    Text(DateFormat('dd MMM yyyy').format(_date), style: TextStyle(color: _editing ? null : Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Read-only info
            _InfoRow(label: 'Paid by', value: paidByName),
            _InfoRow(label: 'Month', value: widget.bill.month),

            if (widget.bill.receiptUrl != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showReceipt(widget.bill.receiptUrl!),
                icon: const Icon(Icons.image, size: 18),
                label: const Text('View Receipt'),
              ),
            ],

            if (_editing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
