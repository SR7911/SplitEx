import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';

class PersonalDebtsScreen extends ConsumerWidget {
  const PersonalDebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(personalDebtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debts & Settlements')),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allDebts) {
          final unsettled = allDebts.where((t) => !t.isSettled).toList();
          final lentTxns = unsettled.where((t) => t.debtType == DebtType.lent).toList();
          final borrowedTxns = unsettled.where((t) => t.debtType == DebtType.borrowed).toList();

          // Compute totals
          final totalLent = lentTxns.fold<double>(0, (s, t) => s + t.amount);
          final totalBorrowed = borrowedTxns.fold<double>(0, (s, t) => s + t.amount);

          if (unsettled.isEmpty) {
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
              // Summary row
              Row(
                children: [
                  _SummaryChip(
                    label: 'You Lent',
                    subtitle: 'They owe you',
                    amount: totalLent,
                    color: Colors.green,
                    icon: Icons.call_made,
                  ),
                  const SizedBox(width: 12),
                  _SummaryChip(
                    label: 'You Borrowed',
                    subtitle: 'You owe them',
                    amount: totalBorrowed,
                    color: Colors.red,
                    icon: Icons.call_received,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lent section
              if (lentTxns.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Money You Lent',
                  subtitle: 'People who owe you',
                  color: Colors.green,
                  icon: Icons.call_made,
                ),
                const SizedBox(height: 10),
                ...lentTxns.map((t) => _DebtTile(txn: t, isLent: true)),
                const SizedBox(height: 24),
              ],

              // Borrowed section
              if (borrowedTxns.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Money You Borrowed',
                  subtitle: 'People you owe',
                  color: Colors.red,
                  icon: Icons.call_received,
                ),
                const SizedBox(height: 10),
                ...borrowedTxns.map((t) => _DebtTile(txn: t, isLent: false)),
              ],
            ],
          );
        },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: Text(
              personName[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(personName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  txn.title,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${txn.category} • ${DateFormat('dd MMM').format(txn.date)}',
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${txn.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _confirmSettle(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isLent ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLent ? 'Settled?' : 'Settle Up',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isLent ? Colors.green : Colors.orange.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmSettle(BuildContext context, WidgetRef ref) {
    final personName = txn.personName ?? 'Unknown';
    final message = isLent
        ? 'Has $personName paid you back ₹${txn.amount.toStringAsFixed(0)} for "${txn.title}"?'
        : 'Have you paid ₹${txn.amount.toStringAsFixed(0)} back to $personName for "${txn.title}"?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLent ? 'Mark as Settled?' : 'Settle Up?'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = ref.read(authStateProvider).valueOrNull?.uid;
              if (userId == null) return;
              await ref.read(personalExpenseServiceProvider).settleTransaction(userId, txn.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isLent ? 'Marked as settled!' : 'Payment recorded!')),
                );
              }
            },
            child: Text(isLent ? 'Yes, Settled' : 'Yes, Paid'),
          ),
        ],
      ),
    );
  }
}
