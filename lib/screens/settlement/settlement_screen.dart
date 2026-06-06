import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/settlement_model.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/providers/settlement_provider.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/services/balance_service.dart';
import 'package:split_ex/services/user_service.dart';
import 'package:split_ex/screens/settlement/upi_id_dialog.dart';

class SettlementScreen extends ConsumerWidget {
  final String roomId;
  final Debt debt;
  final Map<String, String> nameMap;

  const SettlementScreen({
    super.key,
    required this.roomId,
    required this.debt,
    required this.nameMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final toName = nameMap[debt.to] ?? debt.to;

    return Scaffold(
      appBar: AppBar(title: const Text('Settle Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.payment, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      'Pay $toName',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${debt.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pay via UPI button
            FilledButton.icon(
              onPressed: () => _launchUpi(context, ref, toName),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Pay via UPI'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),

            // Mark as paid button
            OutlinedButton.icon(
              onPressed: () => _markAsPaid(context, ref),
              icon: const Icon(Icons.check),
              label: const Text('Mark as Paid (Cash/Bank Transfer)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),
            Text('Settlement History',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(child: _SettlementHistory(roomId: roomId, nameMap: nameMap)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUpi(BuildContext context, WidgetRef ref, String payeeName) async {
    // Look up payee's profile to get their UPI ID
    final payeeProfile = await UserService().getUserProfile(debt.to);
    final upiId = payeeProfile?.upiId;

    if (upiId == null || upiId.isEmpty) {
      // Payee hasn't set a UPI ID — inform the user and offer options
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('UPI ID Not Set'),
          content: Text('${nameMap[debt.to] ?? debt.to} has not set a UPI ID.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Allow current user to mark as paid manually
                _markAsPaid(context, ref);
              },
              child: const Text('Mark as Paid'),
            ),
          ],
        ),
      );
      return;
    }

    final launched = await ref.read(upiServiceProvider).launchPayment(
          upiId: upiId,
          payeeName: payeeName,
          amount: debt.amount,
          note: 'SplitEx settlement',
        );

    if (!context.mounted) return;

    if (launched) {
      await _createSettlement(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded as pending')),
        );
      }
    } else {
      // No UPI app found — show dialog with options
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No UPI App Found'),
            content: const Text(
                'No UPI app detected on this device. You can mark the payment as done manually.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _markAsPaid(context, ref);
                },
                child: const Text('Mark as Paid'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
            'Mark ₹${debt.amount.toStringAsFixed(2)} as paid to ${nameMap[debt.to] ?? debt.to}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) {
      await _createSettlement(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement recorded!')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _createSettlement(WidgetRef ref) async {
    final settlement = SettlementModel(
      id: '',
      roomId: roomId,
      fromUserId: debt.from,
      toUserId: debt.to,
      amount: debt.amount,
      createdAt: DateTime.now(),
    );
    await ref.read(settlementServiceProvider).createSettlement(roomId, settlement);
    ref.read(activityServiceProvider).log(
      roomId: roomId,
      type: ActivityType.settlementCreated,
      performedBy: debt.from,
      description: '${nameMap[debt.from] ?? debt.from} paid ₹${debt.amount.toStringAsFixed(0)} to ${nameMap[debt.to] ?? debt.to}',
      metadata: {
        'amount': debt.amount,
        'from': debt.from,
        'to': debt.to,
      },
    );
  }
}

class _SettlementHistory extends ConsumerWidget {
  final String roomId;
  final Map<String, String> nameMap;
  const _SettlementHistory({required this.roomId, required this.nameMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(settlementsStreamProvider(roomId));

    return settlementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (settlements) {
        if (settlements.isEmpty) {
          return const Center(child: Text('No settlements yet'));
        }
        return ListView.builder(
          itemCount: settlements.length,
          itemBuilder: (context, index) {
            final s = settlements[index];
            final from = nameMap[s.fromUserId] ?? s.fromUserId;
            final to = nameMap[s.toUserId] ?? s.toUserId;
            final isPending = s.status == SettlementStatus.pending;
            final userId = ref.watch(currentUserIdProvider);
            final canConfirm = isPending && s.toUserId == userId;

            return Card(
              child: ListTile(
                leading: Icon(
                  isPending ? Icons.hourglass_top : Icons.check_circle,
                  color: isPending ? Colors.orange : Colors.green,
                ),
                title: Text('$from → $to'),
                subtitle: Text(
                  '₹${s.amount.toStringAsFixed(0)} • ${DateFormat('dd MMM').format(s.createdAt)}',
                ),
                trailing: canConfirm
                    ? FilledButton(
                        onPressed: () => ref
                            .read(settlementServiceProvider)
                            .confirmSettlement(roomId, s.id),
                        child: const Text('Confirm'),
                      )
                    : Text(
                        isPending ? 'Pending' : 'Done ✓',
                        style: TextStyle(
                          color: isPending ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
