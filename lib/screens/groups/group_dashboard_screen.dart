import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/group_expense_model.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/groups/group_expense_sheet.dart';
import 'package:split_ex/services/balance_service.dart';

class GroupDashboardScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends ConsumerState<GroupDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));
    final uid = ref.watch(currentUserIdProvider);

    return groupAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (group) {
        if (group == null) return const Scaffold(body: Center(child: Text('Group not found')));
        final isAdmin = group.isAdmin(uid);
        final isArchived = group.isArchived;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (isAdmin)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'archive') {
                      await ref.read(groupServiceProvider).archiveGroup(widget.groupId);
                      if (context.mounted) context.pop();
                    } else if (v == 'restore') {
                      await ref.read(groupServiceProvider).restoreGroup(widget.groupId);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isArchived)
                      const PopupMenuItem(value: 'archive', child: Text('Archive Group')),
                    if (isArchived)
                      const PopupMenuItem(value: 'restore', child: Text('Restore Group')),
                  ],
                ),
              if (!isAdmin)
                IconButton(
                  icon: const Icon(Icons.exit_to_app),
                  tooltip: 'Leave Group',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Leave Group?'),
                        content: const Text('You will no longer have access to this group.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await ref.read(groupServiceProvider).leaveGroup(widget.groupId, uid);
                      if (context.mounted) context.pop();
                    }
                  },
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Expenses'),
                Tab(text: 'Settle Up'),
              ],
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              indicatorSize: TabBarIndicatorSize.label,
            ),
          ),
          floatingActionButton: isArchived
              ? null
              : FloatingActionButton(
                  onPressed: () => showGroupExpenseSheet(context, groupId: widget.groupId, memberIds: group.memberIds),
                  child: const Icon(Icons.add),
                ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(groupId: widget.groupId, inviteCode: group.inviteCode),
              _ExpensesTab(groupId: widget.groupId, isArchived: isArchived),
              _SettleUpTab(groupId: widget.groupId),
            ],
          ),
        );
      },
    );
  }
}

// ─── Overview Tab ───────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final String groupId;
  final String inviteCode;
  const _OverviewTab({required this.groupId, required this.inviteCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(groupTotalExpenseProvider(groupId));
    final myBalance = ref.watch(groupUserBalanceProvider(groupId));
    final isOwed = myBalance > 0.01;
    final owes = myBalance < -0.01;
    final balanceColor = isOwed ? Colors.green : owes ? Colors.red : Colors.grey;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Total Expenses', value: '₹${total.toStringAsFixed(0)}', icon: Icons.receipt_long, color: Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: isOwed ? 'You are owed' : owes ? 'You owe' : 'All settled',
                value: myBalance.abs() < 0.01 ? '✓' : '₹${myBalance.abs().toStringAsFixed(0)}',
                icon: isOwed ? Icons.arrow_downward : owes ? Icons.arrow_upward : Icons.check_circle,
                color: balanceColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Invite code card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invite Code', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(inviteCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Recent expenses
        _RecentExpensesCard(groupId: groupId),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _RecentExpensesCard extends ConsumerWidget {
  final String groupId;
  const _RecentExpensesCard({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));
    final expenses = expensesAsync.valueOrNull?.take(5).toList() ?? [];
    if (expenses.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Expenses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            ...expenses.map((e) => _ExpenseTile(expense: e)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final GroupExpenseModel expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  '${expense.category} • ${DateFormat('dd MMM').format(expense.date)}',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Text('₹${expense.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Expenses Tab ────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final bool isArchived;
  const _ExpensesTab({required this.groupId, required this.isArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No expenses yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e = expenses[i];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${e.category} • ${DateFormat('dd MMM yyyy').format(e.date)} • ${e.splitAmong.length} people',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('÷${e.splitAmong.length}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                onLongPress: isArchived
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Expense?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(groupExpenseServiceProvider).deleteExpense(groupId, e.id);
                        }
                      },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Settle Up Tab ───────────────────────────────────────────────────────────

class _SettleUpTab extends ConsumerWidget {
  final String groupId;
  const _SettleUpTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(groupSimplifiedDebtsProvider(groupId));
    final uid = ref.watch(currentUserIdProvider);

    if (debts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text('All settled up!', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: debts.map((debt) {
        final isMyDebt = debt.from == uid;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isMyDebt ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              child: Icon(
                isMyDebt ? Icons.arrow_upward : Icons.arrow_downward,
                color: isMyDebt ? Colors.red : Colors.green,
                size: 20,
              ),
            ),
            title: Text(
              isMyDebt ? 'You owe ${debt.to}' : '${debt.from} owes you',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              '₹${debt.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isMyDebt ? Colors.red : Colors.green,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
