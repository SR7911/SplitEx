import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/group_expense_model.dart';
import 'package:split_ex/models/group_model.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/groups/group_expense_sheet.dart';
import 'package:split_ex/screens/groups/group_reports_screen.dart';
import 'package:split_ex/screens/groups/group_settlement_screen.dart';
import 'package:split_ex/services/balance_service.dart';

class GroupDashboardScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends ConsumerState<GroupDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'Reports',
                onPressed: () => showGroupReportsSheet(context, widget.groupId),
              ),
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
            ),
          ),
          floatingActionButton: isArchived
              ? null
              : FloatingActionButton(
                  onPressed: () => showGroupExpenseSheet(
                    context,
                    groupId: widget.groupId,
                    memberIds: group.memberIds,
                  ),
                  child: const Icon(Icons.add),
                ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(groupId: widget.groupId, inviteCode: group.inviteCode, group: group, onViewAllExpenses: () => _tabController.animateTo(1), onSettleUp: () => _tabController.animateTo(2)),
              _ExpensesTab(groupId: widget.groupId, isArchived: isArchived, memberIds: group.memberIds),
              _SettleUpTab(groupId: widget.groupId, memberIds: group.memberIds),
            ],
          ),
        );
      },
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final String groupId;
  final String inviteCode;
  final GroupModel group;
  final VoidCallback onViewAllExpenses;
  final VoidCallback onSettleUp;
  const _OverviewTab({required this.groupId, required this.inviteCode, required this.group, required this.onViewAllExpenses, required this.onSettleUp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(groupTotalExpenseProvider(groupId));
    final myBalance = ref.watch(groupUserBalanceProvider(groupId));
    final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull ?? [];
    final categoryBreakdown = ref.watch(groupCategoryBreakdownProvider(groupId));
    final netBalances = ref.watch(groupNetBalancesProvider(groupId));
    final membersAsync = ref.watch(roomMembersProvider(group.memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _GroupHeroCard(total: total, myBalance: myBalance, group: group),
        const SizedBox(height: 12),
        _GroupQuickActions(groupId: groupId, memberIds: group.memberIds, onExpensesTab: onViewAllExpenses, onSettleUpTab: onSettleUp),
        const SizedBox(height: 12),
        if (expenses.isNotEmpty) ...[
          _InsightsCard(expenses: expenses, total: total, categoryBreakdown: categoryBreakdown),
          const SizedBox(height: 12),
        ],
        _MemberBalancesCard(netBalances: netBalances, nameMap: nameMap),
        const SizedBox(height: 12),
        _RecentExpensesCard(groupId: groupId, memberIds: group.memberIds, onViewAll: onViewAllExpenses),
        const SizedBox(height: 12),
        _InviteCodeCard(inviteCode: inviteCode),
      ],
    );
  }
}

class _GroupHeroCard extends StatelessWidget {
  final double total;
  final double myBalance;
  final GroupModel group;
  const _GroupHeroCard({required this.total, required this.myBalance, required this.group});

  @override
  Widget build(BuildContext context) {
    final isOwed = myBalance > 0.01;
    final owes = myBalance < -0.01;
    final settled = !isOwed && !owes;
    final primary = Theme.of(context).colorScheme.primary;
    final balanceColor = isOwed ? const Color(0xFF4ADE80) : owes ? const Color(0xFFF87171) : Colors.white70;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Geometric circles — top right
          Positioned(
            top: -28,
            right: -28,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 40,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          // Bottom left circle
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: group name + member badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberIds.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Main figures row
                Row(
                  children: [
                    // Total spending
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Spent',
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                          ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: total),
                            duration: const Duration(milliseconds: 700),
                            builder: (_, v, __) => Text(
                              '₹${v.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white.withOpacity(0.2),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    // My balance
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settled ? 'Status' : isOwed ? 'You are owed' : 'You owe',
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                          ),
                          const SizedBox(height: 4),
                          settled
                              ? Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    const Text('Settled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                                  ],
                                )
                              : TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: myBalance.abs()),
                                  duration: const Duration(milliseconds: 700),
                                  builder: (_, v, __) => Text(
                                    '₹${v.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: balanceColor,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bottom status bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        settled ? Icons.check_circle_outline : isOwed ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 14,
                        color: balanceColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settled
                            ? 'All balances are settled'
                            : isOwed
                                ? 'Others owe you money'
                                : 'You have pending payments',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM yyyy').format(group.startDate),
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<GroupExpenseModel> expenses;
  final double total;
  final Map<String, double> categoryBreakdown;
  const _InsightsCard({required this.expenses, required this.total, required this.categoryBreakdown});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avg = total / expenses.length;
    final topCat = categoryBreakdown.entries.isEmpty
        ? null
        : categoryBreakdown.entries.reduce((a, b) => a.value > b.value ? a : b);
    final topPct = topCat != null && total > 0
        ? (topCat.value / total * 100).toStringAsFixed(0)
        : '0';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text('Spending Insights',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InsightTile(
                  icon: Icons.calculate_outlined,
                  label: 'Avg expense',
                  value: '₹${_fmt(avg)}',
                  color: Colors.indigo,
                ),
                const SizedBox(width: 10),
                _InsightTile(
                  icon: Icons.category_outlined,
                  label: 'Top category',
                  value: topCat != null ? '${topCat.key} ($topPct%)' : '—',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _InsightTile(
                  icon: Icons.groups_outlined,
                  label: 'Members',
                  value: '${expenses.map((e) => e.paidBy).toSet().length} active',
                  color: Colors.teal,
                ),
                const SizedBox(width: 10),
                _InsightTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Total expenses',
                  value: '${expenses.length}',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InsightTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberBalancesCard extends StatelessWidget {
  final Map<String, double> netBalances;
  final Map<String, String> nameMap;
  const _MemberBalancesCard({required this.netBalances, required this.nameMap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (netBalances.isEmpty) return const SizedBox.shrink();

    final sorted = netBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text('Member Balances',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            ...sorted.map((entry) {
              final name = nameMap[entry.key] ?? entry.key.substring(0, 6);
              final isOwed = entry.value > 0.01;
              final owes = entry.value < -0.01;
              final color = isOwed
                  ? const Color(0xFF10B981)
                  : owes
                      ? const Color(0xFFEF4444)
                      : cs.onSurface.withOpacity(0.4);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withOpacity(0.12),
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                    ),
                    Text(
                      isOwed
                          ? 'gets back ₹${entry.value.toStringAsFixed(0)}'
                          : owes
                              ? 'owes ₹${entry.value.abs().toStringAsFixed(0)}'
                              : 'settled',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GroupQuickActions extends ConsumerWidget {
  final String groupId;
  final List<String> memberIds;
  final VoidCallback onExpensesTab;
  final VoidCallback onSettleUpTab;
  const _GroupQuickActions({required this.groupId, required this.memberIds, required this.onExpensesTab, required this.onSettleUpTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile(IconData icon, String label, Color color, VoidCallback onTap) =>
        Expanded(
          child: _QuickActionTile(icon: icon, label: label, color: color, onTap: onTap, isDark: isDark),
        );

    const gap = SizedBox(width: 8);
    final group = ref.watch(groupStreamProvider(groupId)).valueOrNull;

    return Row(
      children: [
        tile(Icons.add_circle_outline, 'Add Expense', Colors.indigo,
            () => showGroupExpenseSheet(context, groupId: groupId, memberIds: memberIds)),
        gap,
        tile(Icons.bar_chart_rounded, 'Reports', Colors.purple,
            () => showGroupReportsSheet(context, groupId)),
        gap,
        tile(Icons.receipt_long_outlined, 'Expenses', Colors.blue, onExpensesTab),
        gap,
        tile(Icons.handshake_outlined, 'Settle Up', Colors.orange, onSettleUpTab),
        gap,
        tile(Icons.link_rounded, 'Invite', Colors.green, () {
          Clipboard.setData(ClipboardData(text: group?.inviteCode ?? groupId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite code copied!')),
          );
        }),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;
  const _QuickActionTile({required this.icon, required this.label, required this.color, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RecentExpensesCard extends ConsumerWidget {
  final String groupId;
  final List<String> memberIds;
  final VoidCallback onViewAll;
  const _RecentExpensesCard({required this.groupId, required this.memberIds, required this.onViewAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull?.take(5).toList() ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Recent Expenses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                const Spacer(),
                GestureDetector(
                  onTap: onViewAll,
                  child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text('No expenses yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ...expenses.asMap().entries.map((entry) {
                final isLast = entry.key == expenses.length - 1;
                return Column(
                  children: [
                    _ExpenseTile(expense: entry.value, groupId: groupId, memberIds: memberIds),
                    if (!isLast) const Divider(height: 1, indent: 0),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  const _InviteCodeCard({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.link_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invite Code', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(inviteCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
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
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final GroupExpenseModel expense;
  final String groupId;
  final List<String> memberIds;
  const _ExpenseTile({required this.expense, required this.groupId, required this.memberIds});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showViewGroupExpenseSheet(
        context,
        groupId: groupId,
        memberIds: memberIds,
        expense: expense,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Expenses Tab ─────────────────────────────────────────────────────────────

enum _GroupSortOption { timeDesc, timeAsc, amountDesc, amountAsc }

class _ExpensesTab extends ConsumerStatefulWidget {
  final String groupId;
  final bool isArchived;
  final List<String> memberIds;
  const _ExpensesTab({required this.groupId, required this.isArchived, required this.memberIds});

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  String? _filterCategory;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  _GroupSortOption _sortOption = _GroupSortOption.timeDesc;

  bool get _hasActiveFilters =>
      _filterCategory != null || _filterDateFrom != null || _filterDateTo != null;

  void _clearFilters() => setState(() {
        _filterCategory = null;
        _filterDateFrom = null;
        _filterDateTo = null;
      });

  List<GroupExpenseModel> _applyFiltersAndSort(List<GroupExpenseModel> expenses) {
    var filtered = expenses.where((e) {
      if (_filterCategory != null && e.category != _filterCategory) return false;
      if (_filterDateFrom != null && e.date.isBefore(_filterDateFrom!)) return false;
      if (_filterDateTo != null && e.date.isAfter(_filterDateTo!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
    switch (_sortOption) {
      case _GroupSortOption.timeDesc: filtered.sort((a, b) => b.date.compareTo(a.date));
      case _GroupSortOption.timeAsc: filtered.sort((a, b) => a.date.compareTo(b.date));
      case _GroupSortOption.amountDesc: filtered.sort((a, b) => b.amount.compareTo(a.amount));
      case _GroupSortOption.amountAsc: filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return filtered;
  }

  void _showFilterSheet(List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GroupFilterBottomSheet(
        categories: categories,
        filterCategory: _filterCategory,
        filterDateFrom: _filterDateFrom,
        filterDateTo: _filterDateTo,
        sortOption: _sortOption,
        onApply: (category, from, to, sort) {
          setState(() {
            _filterCategory = category;
            _filterDateFrom = from;
            _filterDateTo = to;
            _sortOption = sort;
          });
          Navigator.pop(ctx);
        },
        onClear: () {
          _clearFilters();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _sortChip(String label, _GroupSortOption option) {
    final selected = _sortOption == option;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _sortOption = option),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(groupExpensesProvider(widget.groupId));

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final categories = expenses.map((e) => e.category).toSet().toList()..sort();
        final filtered = _applyFiltersAndSort(expenses);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _sortChip('Newest', _GroupSortOption.timeDesc),
                            const SizedBox(width: 6),
                            _sortChip('Oldest', _GroupSortOption.timeAsc),
                            const SizedBox(width: 6),
                            _sortChip('Amount ↑', _GroupSortOption.amountAsc),
                            const SizedBox(width: 6),
                            _sortChip('Amount ↓', _GroupSortOption.amountDesc),
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: const Text('Clear', style: TextStyle(fontSize: 11)),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: _clearFilters,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showFilterSheet(categories),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _hasActiveFilters
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune,
                          size: 20,
                          color: _hasActiveFilters ? Colors.white : Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(_hasActiveFilters ? 'No expenses match filters' : 'No expenses yet',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            onTap: widget.isArchived
                                ? null
                                : () => showViewGroupExpenseSheet(
                                      context,
                                      groupId: widget.groupId,
                                      memberIds: widget.memberIds,
                                      expense: e,
                                    ),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 20),
                            ),
                            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${e.category} • ${DateFormat('dd MMM yyyy').format(e.date)} • ${e.splitAmong.length} people',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('÷${e.splitAmong.length}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                if (!widget.isArchived)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        showEditGroupExpenseSheet(context, groupId: widget.groupId, memberIds: widget.memberIds, expense: e);
                                      } else if (v == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Expense?'),
                                            content: Text('Delete "${e.title}"?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true && context.mounted) {
                                          await ref.read(groupExpenseServiceProvider).deleteExpense(widget.groupId, e.id);
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupFilterBottomSheet extends StatefulWidget {
  final List<String> categories;
  final String? filterCategory;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final _GroupSortOption sortOption;
  final void Function(String?, DateTime?, DateTime?, _GroupSortOption) onApply;
  final VoidCallback onClear;

  const _GroupFilterBottomSheet({
    required this.categories,
    required this.filterCategory,
    required this.filterDateFrom,
    required this.filterDateTo,
    required this.sortOption,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_GroupFilterBottomSheet> createState() => _GroupFilterBottomSheetState();
}

class _GroupFilterBottomSheetState extends State<_GroupFilterBottomSheet> {
  late String? _category;
  late DateTime? _from;
  late DateTime? _to;
  late _GroupSortOption _sort;

  @override
  void initState() {
    super.initState();
    _category = widget.filterCategory;
    _from = widget.filterDateFrom;
    _to = widget.filterDateTo;
    _sort = widget.sortOption;
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleMedium),
              TextButton(onPressed: widget.onClear, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.categories.isNotEmpty) ...[
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: [
                ChoiceChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                ...widget.categories.map((c) => ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c))),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Text('Date range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(_from != null ? DateFormat('dd MMM').format(_from!) : 'From'))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
              Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(_to != null ? DateFormat('dd MMM').format(_to!) : 'To'))),
              if (_from != null || _to != null)
                IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _from = null; _to = null; })),
            ],
          ),
          const SizedBox(height: 14),
          Text('Sort by', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Newest'), selected: _sort == _GroupSortOption.timeDesc, onSelected: (_) => setState(() => _sort = _GroupSortOption.timeDesc)),
              ChoiceChip(label: const Text('Oldest'), selected: _sort == _GroupSortOption.timeAsc, onSelected: (_) => setState(() => _sort = _GroupSortOption.timeAsc)),
              ChoiceChip(label: const Text('Amount ↑'), selected: _sort == _GroupSortOption.amountAsc, onSelected: (_) => setState(() => _sort = _GroupSortOption.amountAsc)),
              ChoiceChip(label: const Text('Amount ↓'), selected: _sort == _GroupSortOption.amountDesc, onSelected: (_) => setState(() => _sort = _GroupSortOption.amountDesc)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onApply(_category, _from, _to, _sort),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settle Up Tab ────────────────────────────────────────────────────────────

class _SettleUpTab extends ConsumerWidget {
  final String groupId;
  final List<String> memberIds;
  const _SettleUpTab({required this.groupId, required this.memberIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(groupSimplifiedDebtsProvider(groupId));
    final uid = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(roomMembersProvider(memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: debts.map((debt) {
        final isMyDebt = debt.from == uid;
        final fromName = nameMap[debt.from] ?? debt.from;
        final toName = nameMap[debt.to] ?? debt.to;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupSettlementScreen(
                  groupId: groupId,
                  debt: debt,
                  nameMap: nameMap,
                ),
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: isMyDebt ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              child: Icon(
                isMyDebt ? Icons.arrow_upward : Icons.arrow_downward,
                color: isMyDebt ? Colors.red : Colors.green,
                size: 20,
              ),
            ),
            title: Text(
              isMyDebt ? 'You owe $toName' : '$fromName owes you',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              isMyDebt ? 'Tap to pay or mark as settled' : 'Tap to send reminder',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${debt.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isMyDebt ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
