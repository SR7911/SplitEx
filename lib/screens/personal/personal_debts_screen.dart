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
    final balances = ref.watch(personalDebtBalancesProvider);
    final debtsAsync = ref.watch(personalDebtsProvider);

    // Sort: largest absolute balance first
    final sorted = balances.entries.toList()..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final totalOwedToYou = sorted.where((e) => e.value > 0).fold<double>(0, (s, e) => s + e.value);
    final totalYouOwe = sorted.where((e) => e.value < 0).fold<double>(0, (s, e) => s + e.value.abs());

    return Scaffold(
      appBar: AppBar(title: const Text('Debts & Settlements')),
      body: sorted.isEmpty
          ? Center(
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
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary row
                Row(
                  children: [
                    _SummaryChip(label: 'Owed to you', amount: totalOwedToYou, color: Colors.green),
                    const SizedBox(width: 12),
                    _SummaryChip(label: 'You owe', amount: totalYouOwe, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 20),
                ...sorted.map((entry) {
                  final name = entry.key;
                  final balance = entry.value;
                  final theyOweYou = balance > 0;
                  final color = theyOweYou ? Colors.green : Colors.red;
                  final label = theyOweYou ? '$name owes you' : 'You owe $name';

                  return _DebtCard(
                    name: name,
                    label: label,
                    amount: balance.abs(),
                    color: color,
                    theyOweYou: theyOweYou,
                    onSettleUp: () => _showSettleSheet(context, ref, name, debtsAsync.valueOrNull ?? []),
                  );
                }),
              ],
            ),
    );
  }

  void _showSettleSheet(BuildContext context, WidgetRef ref, String personName, List<PersonalTransactionModel> allDebts) {
    final unsettled = allDebts.where((t) => t.personName == personName && !t.isSettled).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettleSheet(personName: personName, unsettled: unsettled),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final String name;
  final String label;
  final double amount;
  final Color color;
  final bool theyOweYou;
  final VoidCallback onSettleUp;
  const _DebtCard({required this.name, required this.label, required this.amount, required this.color, required this.theyOweYou, required this.onSettleUp});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(theyOweYou ? Icons.call_made : Icons.call_received, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onSettleUp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Settle Up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettleSheet extends ConsumerWidget {
  final String personName;
  final List<PersonalTransactionModel> unsettled;
  const _SettleSheet({required this.personName, required this.unsettled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: Container(
              width: 48, height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Row(
            children: [
              Icon(Icons.handshake, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 10),
              Text('Settle with $personName', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          if (unsettled.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('All settled!')))
          else ...[
            Text('${unsettled.length} unsettled transaction(s)', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 12),
            ...unsettled.map((t) {
              final isLent = t.debtType == DebtType.lent;
              final color = isLent ? Colors.green : Colors.red;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('${t.category} • ${DateFormat('dd MMM').format(t.date)}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ),
                    Text('₹${t.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        final userId = ref.read(authStateProvider).valueOrNull?.uid;
                        if (userId == null) return;
                        await ref.read(personalExpenseServiceProvider).settleTransaction(userId, t.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settled: ${t.title}')));
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: const Text('Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final userId = ref.read(authStateProvider).valueOrNull?.uid;
                if (userId == null) return;
                final service = ref.read(personalExpenseServiceProvider);
                for (final t in unsettled) {
                  await service.settleTransaction(userId, t.id);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All settled with $personName!')));
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Settle All', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
