import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/widgets/app_header.dart';

class PersonalDebtsScreen extends ConsumerWidget {
  const PersonalDebtsScreen({super.key});

  List<PersonalTransactionModel> _sortedBySettled(List<PersonalTransactionModel> list) {
    final unsettled = list.where((t) => !t.isSettled).toList();
    final settled = list.where((t) => t.isSettled).toList();
    return [...unsettled, ...settled];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(personalDebtsProvider);

    return Scaffold(
      appBar: const AppHeader(showBack: true, title: 'Debts & Settlements', showNotification: false),
      body: GradientBody(
        child: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allDebts) {
          final lentTxns = allDebts.where((t) => t.debtType == DebtType.lent).toList();
          final borrowedTxns = allDebts.where((t) => t.debtType == DebtType.borrowed).toList();

          final totalLent = lentTxns.where((t) => !t.isSettled).fold<double>(0, (s, t) => s + t.remainingAmount);
          final totalBorrowed = borrowedTxns.where((t) => !t.isSettled).fold<double>(0, (s, t) => s + t.remainingAmount);

          if (allDebts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.handshake_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No active debts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Link a person when adding expenses', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _SummaryChip(label: 'You Lent', subtitle: 'They owe you', amount: totalLent, color: Colors.green, icon: Icons.call_made),
                  const SizedBox(width: 12),
                  _SummaryChip(label: 'You Borrowed', subtitle: 'You owe them', amount: totalBorrowed, color: Colors.red, icon: Icons.call_received),
                ],
              ),
              const SizedBox(height: 24),
              if (lentTxns.isNotEmpty) ...[
                _SectionHeader(title: 'Money You Lent', subtitle: 'People who owe you', color: Colors.green, icon: Icons.call_made),
                const SizedBox(height: 10),
                ..._sortedBySettled(lentTxns).map((t) => _DebtTile(txn: t, isLent: true)),
                const SizedBox(height: 24),
              ],
              if (borrowedTxns.isNotEmpty) ...[
                _SectionHeader(title: 'Money You Borrowed', subtitle: 'People you owe', color: Colors.red, icon: Icons.call_received),
                const SizedBox(height: 10),
                ..._sortedBySettled(borrowedTxns).map((t) => _DebtTile(txn: t, isLent: false)),
              ],
            ],
          );
        },
      ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final double amount;
  final Color color;
  final IconData icon;
  const _SummaryChip({required this.label, required this.subtitle, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  const _SectionHeader({required this.title, required this.subtitle, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      ],
    );
  }
}

class _DebtTile extends ConsumerWidget {
  final PersonalTransactionModel txn;
  final bool isLent;
  const _DebtTile({required this.txn, required this.isLent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isLent ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personName = txn.personName ?? 'Unknown';
    final settled = txn.isSettled;
    final hasPartial = txn.settledAmount > 0 && !settled;
    final remaining = txn.remainingAmount;

    return Opacity(
      opacity: settled ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: settled ? Colors.grey : (hasPartial ? Colors.orange : color), width: 3)),
          boxShadow: [
            if (!isDark && !settled) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: (settled ? Colors.grey : color).withOpacity(0.1),
                    child: settled
                        ? const Icon(Icons.check, color: Colors.grey, size: 16)
                        : Text(personName[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(personName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, decoration: settled ? TextDecoration.lineThrough : null)),
                            const SizedBox(width: 6),
                            if (settled)
                              _Pill(label: 'Settled', color: Colors.grey)
                            else if (hasPartial)
                              _Pill(label: 'Partial', color: Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(txn.title, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${txn.category} • ${DateFormat('dd MMM').format(txn.date)}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasPartial) ...[
                        Text('₹${txn.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), decoration: TextDecoration.lineThrough)),
                        Text('₹${remaining.toStringAsFixed(0)} left', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                      ] else
                        Text(
                          '₹${txn.amount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: settled ? Colors.grey : color, decoration: settled ? TextDecoration.lineThrough : null),
                        ),
                      const SizedBox(height: 6),
                      if (!settled)
                        GestureDetector(
                          onTap: () => _showSettleSheet(context, ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isLent ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isLent ? 'Settle?' : 'Settle Up',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLent ? Colors.green : Colors.orange.shade700),
                            ),
                          ),
                        )
                      else
                        Icon(Icons.check_circle, size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
            // Partial settlement history
            if (txn.partialSettlements.isNotEmpty)
              _PartialHistory(settlements: txn.partialSettlements, color: settled ? Colors.grey : color),
          ],
        ),
      ),
    );
  }

  void _showSettleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettleSheet(
        personName: txn.personName ?? 'Unknown',
        totalAmount: txn.amount,
        remainingAmount: txn.remainingAmount,
        isLent: isLent,
        onPartial: (amount, note) async {
          final userId = ref.read(authStateProvider).valueOrNull?.uid;
          if (userId == null) return;
          await ref.read(personalExpenseServiceProvider).partialSettleTransaction(userId, txn.id, amount, note);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('₹${amount.toStringAsFixed(0)} recorded!')));
          }
        },
        onFull: () async {
          final userId = ref.read(authStateProvider).valueOrNull?.uid;
          if (userId == null) return;
          await ref.read(personalExpenseServiceProvider).settleTransaction(userId, txn.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLent ? 'Marked as settled!' : 'Payment recorded!')));
          }
        },
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _PartialHistory extends StatelessWidget {
  final List<Map<String, dynamic>> settlements;
  final Color color;
  const _PartialHistory({required this.settlements, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settlement History', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          ...settlements.map((s) {
            final amount = (s['amount'] ?? 0).toDouble();
            final note = s['note'] as String? ?? '';
            final dateStr = s['date'] as String? ?? '';
            DateTime? date;
            try { date = DateTime.parse(dateStr); } catch (_) {}
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 12, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note.isNotEmpty ? note : 'Payment',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date != null)
                    Text(DateFormat('dd MMM').format(date), style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
                  const SizedBox(width: 8),
                  Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SettleSheet extends StatefulWidget {
  final String personName;
  final double totalAmount;
  final double remainingAmount;
  final bool isLent;
  final Future<void> Function(double amount, String? note) onPartial;
  final Future<void> Function() onFull;
  const _SettleSheet({
    required this.personName,
    required this.totalAmount,
    required this.remainingAmount,
    required this.isLent,
    required this.onPartial,
    required this.onFull,
  });

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.isLent ? Colors.green : Colors.red;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Settle with ${widget.personName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Total: ₹${widget.totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('₹${widget.remainingAmount.toStringAsFixed(0)} remaining', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffix: TextButton(
                  onPressed: () => _amountCtrl.text = widget.remainingAmount.toStringAsFixed(0),
                  child: const Text('Full'),
                ),
              ),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) return 'Enter a valid amount';
                if (val > widget.remainingAmount) return 'Cannot exceed remaining ₹${widget.remainingAmount.toStringAsFixed(0)}';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () async {
                      if (!_formKey.currentState!.validate()) return;
                      final amount = double.parse(_amountCtrl.text);
                      setState(() => _loading = true);
                      Navigator.pop(context);
                      await widget.onPartial(amount, _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim());
                    },
                    child: const Text('Record Partial'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : () async {
                      setState(() => _loading = true);
                      Navigator.pop(context);
                      await widget.onFull();
                    },
                    child: Text(widget.isLent ? 'Mark Settled' : 'Mark Paid'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
