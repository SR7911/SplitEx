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
import 'package:split_ex/widgets/app_header.dart';

// ─── Shared design tokens (mirrors personal_expense_tab) ─────────────────────
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kOrange = Color(0xFFF97316);

BoxDecoration _cardDeco(BuildContext context) {
  final cs     = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? cs.surfaceContainerHigh : cs.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

Widget _sectionTitle(BuildContext context, String title, {Widget? action}) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ),
      if (action != null) action,
    ],
  );
}

Widget _actionChip(BuildContext context, String label, VoidCallback onTap) {
  final cs = Theme.of(context).colorScheme;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
    ),
  );
}

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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            flexibleSpace: _AppBarGradient(),
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
          body: GradientBody(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(groupId: widget.groupId, inviteCode: group.inviteCode, group: group, onViewAllExpenses: () => _tabController.animateTo(1), onSettleUp: () => _tabController.animateTo(2)),
                _ExpensesTab(groupId: widget.groupId, isArchived: isArchived, memberIds: group.memberIds),
                _SettleUpTab(groupId: widget.groupId, memberIds: group.memberIds),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Shared gradient for AppBar flexibleSpace ────────────────────────────────

class _AppBarGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withValues(alpha: isDark ? 0.55 : 0.45),
            primary.withValues(alpha: 0.18),
          ],
        ),
      ),
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
    final isOwed   = myBalance > 0.01;
    final owes     = myBalance < -0.01;
    final settled  = !isOwed && !owes;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isOwed
        ? (isDark ? [const Color(0xFF064E3B), const Color(0xFF065F46)] : [const Color(0xFF059669), const Color(0xFF0D9488)])
        : owes
            ? (isDark ? [const Color(0xFF7F1D1D), const Color(0xFF831843)] : [const Color(0xFFDC2626), const Color(0xFFDB2777)])
            : (isDark ? [const Color(0xFF1E3A5F), const Color(0xFF1E3A8A)] : [const Color(0xFF2563EB), const Color(0xFF4F46E5)]);
    final balanceColor = isOwed ? const Color(0xFF4ADE80) : owes ? const Color(0xFFF87171) : Colors.white70;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: gradientColors.first.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(top: -40, right: -40, child: IgnorePointer(child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06))))),
            Positioned(bottom: -30, left: -30, child: IgnorePointer(child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))))),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(group.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.groups_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${group.memberIds.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(settled ? 'Group Status' : isOwed ? 'You are owed' : 'You owe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.65))),
                  const SizedBox(height: 6),
                  settled
                      ? const Text('All Settled ✓', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1))
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: myBalance.abs()),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text('₹${v.toStringAsFixed(0)}', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: balanceColor, letterSpacing: -1.5, height: 1.1)),
                        ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _HeroChip(icon: Icons.receipt_long_rounded, label: 'Total Spent', value: '₹${total.toStringAsFixed(0)}'),
                      const SizedBox(width: 10),
                      _HeroChip(icon: Icons.calendar_today_rounded, label: 'Since', value: DateFormat('MMM yyyy').format(group.startDate)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.65)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ]),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<GroupExpenseModel> expenses;
  final double total;
  final Map<String, double> categoryBreakdown;
  const _InsightsCard({required this.expenses, required this.total, required this.categoryBreakdown});

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avg    = total / expenses.length;
    final topCat = categoryBreakdown.entries.isEmpty ? null
        : categoryBreakdown.entries.reduce((a, b) => a.value > b.value ? a : b);
    final topPct = topCat != null && total > 0 ? '${(topCat.value / total * 100).toStringAsFixed(0)}%' : '—';

    final stats = [
      (Icons.calculate_outlined,    _kIndigo, 'Avg Expense',    '₹${_fmt(avg)}'),
      (Icons.category_outlined,     _kAmber,  'Top Category',   topCat != null ? '${topCat.key} $topPct' : '—'),
      (Icons.groups_outlined,       _kTeal,   'Active Members', '${expenses.map((e) => e.paidBy).toSet().length}'),
      (Icons.receipt_long_outlined, _kBlue,   'Total Expenses', '${expenses.length}'),
    ];

    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Spending Insights'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _InsightTile(icon: stats[0].$1, color: stats[0].$2, label: stats[0].$3, value: stats[0].$4, isDark: isDark, cs: cs)),
              const SizedBox(width: 10),
              Expanded(child: _InsightTile(icon: stats[1].$1, color: stats[1].$2, label: stats[1].$3, value: stats[1].$4, isDark: isDark, cs: cs)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InsightTile(icon: stats[2].$1, color: stats[2].$2, label: stats[2].$3, value: stats[2].$4, isDark: isDark, cs: cs)),
              const SizedBox(width: 10),
              Expanded(child: _InsightTile(icon: stats[3].$1, color: stats[3].$2, label: stats[3].$3, value: stats[3].$4, isDark: isDark, cs: cs)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isDark;
  final ColorScheme cs;
  const _InsightTile({required this.icon, required this.color, required this.label, required this.value, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ),
        ],
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
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (netBalances.isEmpty) return const SizedBox.shrink();
    final sorted = netBalances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Member Balances'),
          const SizedBox(height: 14),
          ...sorted.asMap().entries.map((entry) {
            final e      = entry.value;
            final name   = nameMap[e.key] ?? e.key.substring(0, 6);
            final isOwed = e.value > 0.01;
            final owes   = e.value < -0.01;
            final color  = isOwed ? _kGreen : owes ? _kRed : cs.onSurface.withValues(alpha: 0.4);
            final isLast = entry.key == sorted.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.07 : 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                      child: Center(
                        child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    ),
                    Text(
                      isOwed ? 'gets back ₹${e.value.toStringAsFixed(0)}'
                          : owes ? 'owes ₹${e.value.abs().toStringAsFixed(0)}'
                          : 'settled',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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
    final group  = ref.watch(groupStreamProvider(groupId)).valueOrNull;

    final actions = [
      (Icons.add_circle_outline_rounded, 'Add',      _kIndigo, () => showGroupExpenseSheet(context, groupId: groupId, memberIds: memberIds)),
      (Icons.bar_chart_rounded,          'Reports',  _kBlue,   () => showGroupReportsSheet(context, groupId)),
      (Icons.receipt_long_outlined,      'Expenses', _kTeal,   onExpensesTab),
      (Icons.handshake_outlined,         'Settle',   _kOrange, onSettleUpTab),
      (Icons.link_rounded,               'Invite',   _kGreen,  () {
        Clipboard.setData(ClipboardData(text: group?.inviteCode ?? groupId));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
      }),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: a.$4,
            child: Container(
              width: 76,
              decoration: BoxDecoration(
                color: a.$3.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: a.$3.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(a.$1, size: 22, color: a.$3),
                  const SizedBox(height: 6),
                  Text(a.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: a.$3)),
                ],
              ),
            ),
          );
        },
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
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final expenses = ref.watch(groupExpensesProvider(groupId)).valueOrNull?.take(5).toList() ?? [];

    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Recent Expenses', action: _actionChip(context, 'View All', onViewAll)),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.receipt_long_outlined, size: 26, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 10),
                    Text('No expenses yet', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...expenses.asMap().entries.map((entry) {
              final e      = entry.value;
              final isLast = entry.key == expenses.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: InkWell(
                  onTap: () => showViewGroupExpenseSheet(context, groupId: groupId, memberIds: memberIds, expense: e),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: isDark ? 0.07 : 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.receipt_long_rounded, size: 16, color: _kBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${e.category} • ${DateFormat('dd MMM').format(e.date)}', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kBlue)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  const _InviteCodeCard({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _kTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.link_rounded, color: _kTeal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite Code', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(inviteCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _kTeal.withValues(alpha: isDark ? 0.12 : 0.08), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.copy_rounded, size: 18, color: _kTeal),
            ),
          ),
        ],
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
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(Icons.receipt_long_outlined, size: 32, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _hasActiveFilters ? 'No expenses match filters' : 'No expenses yet',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e      = filtered[i];
                        final cs     = Theme.of(context).colorScheme;
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          decoration: BoxDecoration(
                            color: _kBlue.withValues(alpha: isDark ? 0.07 : 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _kBlue.withValues(alpha: 0.12)),
                          ),
                          child: InkWell(
                            onTap: widget.isArchived
                                ? null
                                : () => showViewGroupExpenseSheet(context, groupId: widget.groupId, memberIds: widget.memberIds, expense: e),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.receipt_long_rounded, size: 20, color: _kBlue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text('${e.category} • ${DateFormat('dd MMM yyyy').format(e.date)} • ${e.splitAmong.length} people', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kBlue)),
                                      Text('÷${e.splitAmong.length}', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                                    ],
                                  ),
                                  if (!widget.isArchived)
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
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
                                                FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
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
        final toName   = nameMap[debt.to] ?? debt.to;
        final color    = isMyDebt ? _kRed : _kGreen;
        final isDark   = Theme.of(context).brightness == Brightness.dark;
        final cs       = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GroupSettlementScreen(groupId: groupId, debt: debt, nameMap: nameMap)),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.07 : 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                    child: Icon(isMyDebt ? Icons.north_rounded : Icons.south_rounded, size: 20, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMyDebt ? 'You owe $toName' : '$fromName owes you',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMyDebt ? 'Tap to pay or mark as settled' : 'Tap to send reminder',
                          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${debt.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
                      Icon(Icons.chevron_right, size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
