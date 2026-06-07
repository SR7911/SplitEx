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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      BillType.rent => Icons.home_rounded,
      BillType.electricity => Icons.bolt_rounded,
      BillType.water => Icons.water_drop_rounded,
    };
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // Header with icon and edit button
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(billIcon, size: 22, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bill Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  if (_canEdit && !_editing)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: () => setState(() => _editing = true),
                    ),
                  if (_editing)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: _cancelEdit,
                    ),
                ],
              ),
              const Divider(height: 24, thickness: 1, color: Colors.grey),

              // Bill type segmented button (full width)
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<BillType>(
                  segments: const [
                    ButtonSegment(value: BillType.rent, label: Text('Rent'), icon: Icon(Icons.home_rounded, size: 18)),
                    ButtonSegment(value: BillType.electricity, label: Text('EB'), icon: Icon(Icons.bolt_rounded, size: 18)),
                    ButtonSegment(value: BillType.water, label: Text('Water'), icon: Icon(Icons.water_drop_rounded, size: 18)),
                  ],
                  selected: {_billType},
                  onSelectionChanged: _editing ? (v) => setState(() => _billType = v.first) : null,
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
              const SizedBox(height: 18),

              // Amount field
              TextFormField(
                controller: _amountController,
                enabled: _editing,
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
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: _editing ? _pickDate : null,
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
                      Icon(Icons.calendar_today, size: 18, color: _editing ? Colors.grey.shade700 : Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy').format(_date),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                          color: _editing ? null : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Read-only info rows (styled as a card)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Paid by', value: paidByName),
                    const SizedBox(height: 6),
                    _InfoRow(label: 'Month', value: widget.bill.month),
                  ],
                ),
              ),

              // Receipt button (if available)
              if (widget.bill.receiptUrl != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showReceipt(widget.bill.receiptUrl!),
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('View Receipt'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ],

              // Save button (only in edit mode)
              if (_editing) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}