import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/policies/debts/debt_tally.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_commands.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';

class DebtTallySection extends StatelessWidget {
  final List<PersonalTransaction> debts;
  const DebtTallySection({super.key, required this.debts});

  @override
  Widget build(BuildContext context) {
    final people = <String, String>{};
    for (final debt in debts) {
      if (debt.personName == null || debt.remainingAmount <= 0) continue;
      people.putIfAbsent(
        debtPersonKey(debt.personName!),
        () => debt.personName!.trim(),
      );
    }
    final plans =
        [
            for (final person in people.values) planDebtTally(person, debts),
          ].where((plan) => plan.canTally).toList()
          ..sort((a, b) => a.personName.compareTo(b.personName));
    if (plans.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tally opposite debts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Offset what you owe and what you are owed by the same person. No payment is recorded.',
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final plan in plans) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          showDebtTallySheet(context, plan.personName),
                      icon: const Icon(Icons.balance_rounded),
                      label: Text(
                        '${plan.personName} · ₹${(plan.offsetCents / 100).toStringAsFixed(2)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showDebtTallySheet(BuildContext context, String personName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DebtTallySheet(personName: personName),
  );
}

class _DebtTallySheet extends ConsumerStatefulWidget {
  final String personName;
  const _DebtTallySheet({required this.personName});

  @override
  ConsumerState<_DebtTallySheet> createState() => _DebtTallySheetState();
}

class _DebtTallySheetState extends ConsumerState<_DebtTallySheet> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm(DebtTallyPlan preview) async {
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tallyPersonalDebtsProvider)(
        userId,
        widget.personName,
        expectedOffsetCents: preview.offsetCents,
        expectedNetCents: preview.netCents,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debts tallied. No payment was recorded.'),
          ),
        );
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = '$error';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final debts =
        ref.watch(personalDebtTransactionsProvider).valueOrNull ??
        const <PersonalTransaction>[];
    final plan = planDebtTally(widget.personName, debts);
    final formatter = NumberFormat('#,##0.00');
    final affected =
        debts.where((debt) => plan.offsetsCents.containsKey(debt.id)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return FractionallySizedBox(
      heightFactor: .8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tally with ${widget.personName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This offsets opposing balances, oldest debts first. It records a tally in each debt’s history without moving money.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'They owe you: ₹${formatter.format(plan.lentCents / 100)}',
                    ),
                    Text(
                      'You owe them: ₹${formatter.format(plan.borrowedCents / 100)}',
                    ),
                    const Divider(),
                    Text(
                      'Offset now: ₹${formatter.format(plan.offsetCents / 100)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.netCents > 0
                          ? 'After tally: ${widget.personName} owes you ₹${formatter.format(plan.netCents / 100)}'
                          : plan.netCents < 0
                          ? 'After tally: you owe ${widget.personName} ₹${formatter.format(-plan.netCents / 100)}'
                          : 'After tally: both sides are settled',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Debts affected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: affected.length,
                itemBuilder: (_, i) {
                  final debt = affected[i];
                  return ListTile(
                    leading: Icon(
                      debt.debtType == DebtType.lent
                          ? Icons.call_made
                          : Icons.call_received,
                    ),
                    title: Text(debt.title),
                    subtitle: Text(
                      '${debt.debtType == DebtType.lent ? 'Lent' : 'Borrowed'} · ${DateFormat('dd MMM yyyy').format(debt.date)}',
                    ),
                    trailing: Text(
                      '−₹${formatter.format(plan.offsetsCents[debt.id]! / 100)}',
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: !plan.canTally || _busy ? null : () => _confirm(plan),
              child: Text(_busy ? 'Tallying…' : 'Confirm Tally'),
            ),
          ],
        ),
      ),
    );
  }
}
