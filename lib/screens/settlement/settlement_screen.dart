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
import 'package:split_ex/services/notification_helper.dart'; // add this
import 'package:split_ex/providers/notification_provider.dart'; // add if needed

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
    final isDebtor = debt.from == userId;
    final isCreditor = debt.to == userId;
    final otherPartyName = isDebtor
        ? (nameMap[debt.to] ?? debt.to)
        : (nameMap[debt.from] ?? debt.from);

    return Scaffold(
      appBar: AppBar(title: Text(isDebtor ? 'Settle Up' : 'Payment Request')),
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
                    Icon(
                      isDebtor ? Icons.payment : Icons.request_page,
                      size: 48,
                      color: isDebtor ? Colors.orange : Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isDebtor ? 'Pay $otherPartyName' : 'Receive from $otherPartyName',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${debt.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDebtor ? Colors.red : Colors.green,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Different buttons for debtor vs creditor
            if (isDebtor) ...[
              FilledButton.icon(
                onPressed: () => _launchUpi(context, ref, otherPartyName),
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Pay via UPI'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _markAsPaid(context, ref),
                icon: const Icon(Icons.check),
                label: const Text('Mark as Paid (Cash/Bank)'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ] else if (isCreditor) ...[
              OutlinedButton.icon(
                onPressed: () => _sendReminder(context, ref),
                icon: const Icon(Icons.notifications_active),
                label: const Text('Send Reminder'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],

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

  // Add the reminder method
  Future<void> _sendReminder(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Text(
            'Remind ${nameMap[debt.from] ?? debt.from} to pay ₹${debt.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final helper = NotificationHelper(ref.read(notificationServiceProvider));
      await helper.sendReminder(
        roomId: roomId,
        fromName: nameMap[debt.to] ?? 'Someone',
        targetUserId: debt.from,
        amount: debt.amount,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder sent!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reminder: $e')),
        );
      }
    }
  }

  Future<void> _launchUpi(BuildContext context, WidgetRef ref, String payeeName) async {
    // First check if the debt might already be settled (avoid duplicate)
    final existingSettlements = ref.read(settlementsStreamProvider(roomId)).valueOrNull ?? [];
    final alreadySettled = existingSettlements.any(
      (s) => s.fromUserId == debt.from && s.toUserId == debt.to && s.amount == debt.amount && s.status == SettlementStatus.confirmed,
    );
    if (alreadySettled) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This debt has already been settled.')),
      );
      Navigator.pop(context);
      return;
    }

    // Look up payee's profile to get their UPI ID
    String? upiId;
    String? errorMsg;
    try {
      final payeeProfile = await UserService().getUserProfile(debt.to);
      upiId = payeeProfile?.upiId;
      if (upiId == null) {
        errorMsg = 'UPI ID not set by payee.';
      }
    } catch (e) {
      errorMsg = 'Failed to load payee profile. Please check your connection.';
    }

    if (!context.mounted) return;

    if (errorMsg != null || upiId == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Initiate UPI Payment'),
          content: Text(errorMsg ?? '${nameMap[debt.to] ?? debt.to} has not set a UPI ID.'),
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
              child: const Text('Mark as Paid Manually'),
            ),
          ],
        ),
      );
      return;
    }

    // Attempt to launch UPI app
    final launched = await ref.read(upiServiceProvider).launchPayment(
          upiId: upiId!,
          payeeName: payeeName,
          amount: debt.amount,
          note: 'SplitEx settlement',
        );

    if (!context.mounted) return;

    if (launched) {
      // Show confirmation dialog: Did payment succeed?
      final bool? paymentConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Initiated'),
          content: const Text('Has the payment been completed successfully in the UPI app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Record Settlement'),
            ),
          ],
        ),
      );

      if (paymentConfirmed == true) {
        await _createSettlement(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settlement recorded!')),
          );
          Navigator.pop(context);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settlement not recorded. You can try again or mark as paid manually.')),
          );
        }
      }
    } else {
      // No UPI app found
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No UPI App Found'),
          content: const Text('No UPI app detected on this device. You can mark the payment as done manually.'),
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

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    // Check again for duplicate settlement
    final existingSettlements = ref.read(settlementsStreamProvider(roomId)).valueOrNull ?? [];
    final alreadySettled = existingSettlements.any(
      (s) => s.fromUserId == debt.from && s.toUserId == debt.to && s.amount == debt.amount && s.status == SettlementStatus.confirmed,
    );
    if (alreadySettled) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This debt has already been settled.')),
      );
      Navigator.pop(context);
      return;
    }

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
        // Wait a moment so user sees the success message, then pop
        await Future.delayed(const Duration(milliseconds: 800));
        if (context.mounted) Navigator.pop(context);
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
            final isCancelled = s.status == SettlementStatus.cancelled;
            final isConfirmed = s.status == SettlementStatus.confirmed;
            final userId = ref.watch(currentUserIdProvider);
            final canConfirm = isPending && s.toUserId == userId;
            final canCancel = isPending && s.fromUserId == userId;

            return Card(
              child: ListTile(
                leading: Icon(
                  isPending ? Icons.hourglass_top : (isCancelled ? Icons.cancel : Icons.check_circle),
                  color: isPending ? Colors.orange : (isCancelled ? Colors.red : Colors.green),
                ),
                title: Text('$from → $to'),
                subtitle: Text(
                  '₹${s.amount.toStringAsFixed(0)} • ${DateFormat('dd MMM').format(s.createdAt)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canConfirm)
                      FilledButton(
                        onPressed: () async {
                          try {
                            await ref.read(settlementServiceProvider).confirmSettlement(roomId, s.id);
                            ref.read(activityServiceProvider).log(
                              roomId: roomId,
                              type: ActivityType.settlementConfirmed,
                              performedBy: userId,
                              description: '${nameMap[s.toUserId] ?? s.toUserId} confirmed settlement from ${nameMap[s.fromUserId] ?? s.fromUserId} of ₹${s.amount.toStringAsFixed(0)}',
                              metadata: {'settlementId': s.id},
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                          }
                        },
                        child: const Text('Confirm'),
                      ),
                    if (canCancel)
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cancel Settlement'),
                              content: const Text('Are you sure you want to cancel this pending settlement?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await ref.read(settlementServiceProvider).cancelSettlement(roomId, s.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Settlement cancelled')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                        label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                      ),
                    if (isConfirmed)
                      const Text(
                        'Done ✓',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (isCancelled)
                      const Text(
                        'Cancelled',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (isPending && !canConfirm && !canCancel)
                      const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}