import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/dashboard_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/settlement/settlement_screen.dart';
import 'package:split_ex/screens/settlement/upi_id_dialog.dart';
import 'package:split_ex/services/balance_service.dart';
import 'package:split_ex/services/notification_helper.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DashboardScreen({super.key, required this.roomId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _upiDialogShown = false;

  void _checkUpiId() {
    if (_upiDialogShown) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null && !profile.hasUpiId) {
      _upiDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpiIdDialog(userId: ref.read(currentUserIdProvider), allowSkip: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(currentUserBalanceProvider(widget.roomId));
    final userDebts = ref.watch(currentUserDebtsProvider(widget.roomId));
    final allDebts = ref.watch(simplifiedDebtsProvider(widget.roomId));
    final userId = ref.watch(currentUserIdProvider);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    // Trigger UPI check after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpiId());

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (room) {
          if (room == null) return const Center(child: Text('Room not found'));
          final members = room.memberIds;
          final membersAsync = ref.watch(roomMembersProvider(members));

          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (memberList) {
              final nameMap = <String, String>{};
              for (final m in memberList) {
                nameMap[m.uid] = m.name;
              }
              nameMap.putIfAbsent(userId, () => 'You');

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceSummaryCard(balance: balance),
                  const SizedBox(height: 20),
                  if (userDebts.isNotEmpty) ...[
                    Text('Your Settlements',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...userDebts.map((d) => _DebtTile(
                          debt: d,
                          currentUserId: userId,
                          nameMap: nameMap,
                          roomId: widget.roomId,
                        )),
                  ],
                  const SizedBox(height: 20),
                  Text('All Settlements',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (allDebts.isEmpty)
                    const Text('All settled up! 🎉')
                  else
                    ...allDebts.map((d) => _DebtTile(
                          debt: d,
                          currentUserId: userId,
                          nameMap: nameMap,
                          roomId: widget.roomId,
                        )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  final double balance;
  const _BalanceSummaryCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;
    final color = isPositive
        ? Colors.green
        : isNegative
            ? Colors.red
            : Colors.grey;
    final label = isPositive
        ? 'You are owed'
        : isNegative
            ? 'You owe'
            : 'All settled up!';
    final displayAmount = balance.abs();

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isPositive
                  ? Icons.arrow_downward
                  : isNegative
                      ? Icons.arrow_upward
                      : Icons.check_circle,
              color: color,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (isPositive || isNegative)
              Text(
                '₹${displayAmount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  final Debt debt;
  final String currentUserId;
  final Map<String, String> nameMap;
  final String roomId;

  const _DebtTile({
    required this.debt,
    required this.currentUserId,
    required this.nameMap,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromName = debt.from == currentUserId ? 'You' : (nameMap[debt.from] ?? debt.from);
    final toName = debt.to == currentUserId ? 'You' : (nameMap[debt.to] ?? debt.to);
    final canRemind = debt.to == currentUserId;
    final canSettle = debt.from == currentUserId;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text('$fromName → $toName'),
        subtitle: canSettle
            ? TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettlementScreen(
                      roomId: roomId,
                      debt: debt,
                      nameMap: nameMap,
                    ),
                  ),
                ),
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Settle Up'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${debt.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: debt.from == currentUserId ? Colors.red : Colors.green,
              ),
            ),
            if (canRemind)
              IconButton(
                icon: const Icon(Icons.notifications_active, size: 20),
                tooltip: 'Send Reminder',
                onPressed: () {
                  final helper = NotificationHelper(
                      ref.read(notificationServiceProvider));
                  helper.sendReminder(
                    roomId: roomId,
                    fromName: nameMap[currentUserId] ?? 'You',
                    targetUserId: debt.from,
                    amount: debt.amount,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder sent!')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
