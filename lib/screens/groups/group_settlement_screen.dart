import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/settlement_model.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/providers/settlement_provider.dart';
import 'package:split_ex/services/balance_service.dart';
import 'package:split_ex/services/notification_helper.dart';
import 'package:split_ex/services/user_service.dart';

class GroupSettlementScreen extends ConsumerWidget {
  final String groupId;
  final Debt debt;
  final Map<String, String> nameMap;

  const GroupSettlementScreen({
    super.key,
    required this.groupId,
    required this.debt,
    required this.nameMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final isDebtor = debt.from == uid;
    final isCreditor = debt.to == uid;
    final otherName = isDebtor ? (nameMap[debt.to] ?? debt.to) : (nameMap[debt.from] ?? debt.from);

    return Scaffold(
      appBar: AppBar(
        title: Text(isDebtor ? 'Settle Up' : 'Payment Request'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AmountCard(debt: debt, isDebtor: isDebtor, otherName: otherName),
            const SizedBox(height: 24),
            if (isDebtor) ...[
              FilledButton.icon(
                onPressed: () => _launchUpi(context, ref, otherName),
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
                  side: const BorderSide(color: Colors.orange),
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
            Text('Settlement History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: _GroupSettlementHistory(groupId: groupId, nameMap: nameMap),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReminder(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminder'),
        content: Text('Remind ${nameMap[debt.from] ?? debt.from} to pay ₹${debt.amount.toStringAsFixed(0)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final helper = NotificationHelper(ref.read(notificationServiceProvider));
      await helper.sendReminder(
        roomId: groupId,
        fromName: nameMap[debt.to] ?? 'Someone',
        targetUserId: debt.from,
        amount: debt.amount,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder sent!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _launchUpi(BuildContext context, WidgetRef ref, String payeeName) async {
    final existing = ref.read(groupSettlementsProvider(groupId)).valueOrNull ?? [];
    final alreadySettled = existing.any((s) =>
        s.fromUserId == debt.from &&
        s.toUserId == debt.to &&
        s.amount == debt.amount &&
        s.status == SettlementStatus.confirmed);
    if (alreadySettled) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already settled.')));
      Navigator.pop(context);
      return;
    }

    String? upiId;
    String? errorMsg;
    try {
      final profile = await UserService().getUserProfile(debt.to);
      upiId = profile?.upiId;
      if (upiId == null) errorMsg = '${nameMap[debt.to] ?? debt.to} has not set a UPI ID.';
    } catch (_) {
      errorMsg = 'Failed to load payee profile.';
    }

    if (!context.mounted) return;

    if (errorMsg != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Initiate UPI Payment'),
          content: Text(errorMsg!),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () { Navigator.pop(ctx); _markAsPaid(context, ref); },
              child: const Text('Mark as Paid Manually'),
            ),
          ],
        ),
      );
      return;
    }

    final launched = await ref.read(upiServiceProvider).launchPayment(
      upiId: upiId!,
      payeeName: payeeName,
      amount: debt.amount,
      note: 'SplitEx group settlement',
    );

    if (!context.mounted) return;

    if (launched) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Initiated'),
          content: const Text('Has the payment been completed in the UPI app?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Record')),
          ],
        ),
      );
      if (confirmed == true) {
        await _createSettlement(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement recorded!')));
          Navigator.pop(context);
        }
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No UPI App Found'),
          content: const Text('No UPI app detected. You can mark the payment manually.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () { Navigator.pop(ctx); _markAsPaid(context, ref); },
              child: const Text('Mark as Paid'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    final existing = ref.read(groupSettlementsProvider(groupId)).valueOrNull ?? [];
    final alreadySettled = existing.any((s) =>
        s.fromUserId == debt.from &&
        s.toUserId == debt.to &&
        s.amount == debt.amount &&
        s.status == SettlementStatus.confirmed);
    if (alreadySettled) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already settled.')));
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Mark ₹${debt.amount.toStringAsFixed(2)} as paid to ${nameMap[debt.to] ?? debt.to}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) {
      await _createSettlement(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement recorded!')));
        await Future.delayed(const Duration(milliseconds: 600));
        if (context.mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _createSettlement(WidgetRef ref) async {
    final settlement = SettlementModel(
      id: '',
      roomId: groupId,
      fromUserId: debt.from,
      toUserId: debt.to,
      amount: debt.amount,
      createdAt: DateTime.now(),
    );
    await ref.read(groupSettlementServiceProvider).createSettlement(groupId, settlement);
  }
}

// ─── Amount Card ──────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final Debt debt;
  final bool isDebtor;
  final String otherName;
  const _AmountCard({required this.debt, required this.isDebtor, required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: (isDebtor ? Colors.orange : Colors.blue).withOpacity(0.1),
              child: Icon(
                isDebtor ? Icons.payment : Icons.request_page,
                size: 32,
                color: isDebtor ? Colors.orange : Colors.blue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isDebtor ? 'Pay $otherName' : 'Receive from $otherName',
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
    );
  }
}

// ─── Settlement History ───────────────────────────────────────────────────────

class _GroupSettlementHistory extends ConsumerWidget {
  final String groupId;
  final Map<String, String> nameMap;
  const _GroupSettlementHistory({required this.groupId, required this.nameMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsAsync = ref.watch(groupSettlementsProvider(groupId));
    final uid = ref.watch(currentUserIdProvider);

    return settlementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (settlements) {
        if (settlements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text('No settlements yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: settlements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final s = settlements[i];
            final from = nameMap[s.fromUserId] ?? s.fromUserId;
            final to = nameMap[s.toUserId] ?? s.toUserId;
            final isPending = s.status == SettlementStatus.pending;
            final isConfirmed = s.status == SettlementStatus.confirmed;
            final isCancelled = s.status == SettlementStatus.cancelled;
            final canConfirm = isPending && s.toUserId == uid;
            final canCancel = isPending && s.fromUserId == uid;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isPending
                          ? Colors.orange
                          : isConfirmed
                              ? Colors.green
                              : Colors.red)
                      .withOpacity(0.1),
                  child: Icon(
                    isPending
                        ? Icons.hourglass_top
                        : isConfirmed
                            ? Icons.check_circle
                            : Icons.cancel,
                    size: 20,
                    color: isPending
                        ? Colors.orange
                        : isConfirmed
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
                title: Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(
                  '₹${s.amount.toStringAsFixed(0)} • ${DateFormat('dd MMM yyyy').format(s.createdAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _SettlementActions(
                  settlement: s,
                  groupId: groupId,
                  nameMap: nameMap,
                  canConfirm: canConfirm,
                  canCancel: canCancel,
                  isConfirmed: isConfirmed,
                  isCancelled: isCancelled,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettlementActions extends ConsumerWidget {
  final SettlementModel settlement;
  final String groupId;
  final Map<String, String> nameMap;
  final bool canConfirm;
  final bool canCancel;
  final bool isConfirmed;
  final bool isCancelled;

  const _SettlementActions({
    required this.settlement,
    required this.groupId,
    required this.nameMap,
    required this.canConfirm,
    required this.canCancel,
    required this.isConfirmed,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isConfirmed) {
      return const Text('Done ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    if (isCancelled) {
      return const Text('Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
    }
    if (canConfirm) {
      return FilledButton(
        onPressed: () async {
          await ref.read(groupSettlementServiceProvider).confirmSettlement(groupId, settlement.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settlement confirmed!')));
          }
        },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Confirm'),
      );
    }
    if (canCancel) {
      return TextButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cancel Settlement?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(groupSettlementServiceProvider).cancelSettlement(groupId, settlement.id);
          }
        },
        child: const Text('Cancel', style: TextStyle(color: Colors.red)),
      );
    }
    return const Text('Pending', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
  }
}
