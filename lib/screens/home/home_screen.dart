import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/dashboard_provider.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/expense/add_expense_sheet.dart';
import 'package:split_ex/screens/groups/groups_list_screen.dart';
import 'package:split_ex/screens/personal/personal_expense_tab.dart';
import 'package:split_ex/screens/projects/projects_list_screen.dart';
import 'package:split_ex/screens/home/room_tab.dart';
import 'package:split_ex/services/recurring_processor.dart';
import 'package:split_ex/services/user_service.dart';
import 'package:split_ex/screens/settlement/upi_id_dialog.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selectedMonth;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _processRecurring();
  }

  void _processRecurring() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authStateProvider).valueOrNull?.uid;
      if (userId != null) {
        RecurringProcessor().processRecurring(userId);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() => setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      });

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }

  void _onNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  Future<bool> checkUpiExist() async {
    final userId = ref.read(currentUserIdProvider);
    var profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      profile = await UserService().getUserProfile(userId);
    }
    if (profile == null || profile.upiId == null || profile.upiId!.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('UPI ID Required'),
          content: const Text(
            'To enter a room you must add your primary UPI ID so others can settle payments with you. This is only used to receive money and will not be used for fraud or marketing.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set UPI')),
          ],
        ),
      );

      if (proceed != true) return false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpiIdDialog(userId: userId, allowSkip: false),
      );

      final updated = await UserService().getUserProfile(userId);
      if (updated == null || updated.upiId == null || updated.upiId!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('UPI ID is required to enter a room')),
          );
        }
        return false;
      }
    }
    return true;
  }

  bool get _isCurrentMonth =>
      _selectedMonth.year == DateTime.now().year && _selectedMonth.month == DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final isDeveloper = ref.watch(isDeveloperProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userName = profile?.name ?? 'User';

    return Scaffold(
      appBar: AppHeader(showDate: true, showHamburger: true, showNotification: true),
      drawer: _AppDrawer(userName: userName, userId: userId, isDeveloper: isDeveloper),
      body: GradientBody(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: [
            // Index 0: Personal Expenses
            const PersonalExpenseTab(key: ValueKey('personal')),

            // Index 1: Groups
            const GroupsListScreen(key: ValueKey('groups')),

            // Index 2: Room
            RoomTab(
              key: const ValueKey('room'),
              checkUpiExist: checkUpiExist,
            ),

            // Index 3: Projects
            const ProjectsListScreen(key: ValueKey('projects')),
          ][_selectedIndex],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
}

// ==========================
// Refined Subâ€‘widgets
// ==========================

class _GreetingHeader extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;
  const _GreetingHeader({required this.userName, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, $userName ðŸ‘‹', style: AppTextStyles.sectionTitle(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(monthStr, style: AppTextStyles.bodySmall(context).copyWith(color: cs.primary, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// class _MonthBalanceCard extends ConsumerWidget {
//   final String monthKey;
//   final DateTime selectedMonth;
//   final bool isCurrentMonth;
//   final VoidCallback onPrev;
//   final VoidCallback onNext;
//   const _MonthBalanceCard({required this.monthKey, required this.selectedMonth, required this.isCurrentMonth, required this.onPrev, required this.onNext});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final balance = ref.watch(monthOverallBalanceProvider(monthKey));
//     final isOwed = balance > 0.01;
//     final owes = balance < -0.01;
//     final color = isOwed ? Colors.green.shade500 : owes ? Colors.red.shade500 : Colors.grey.shade500;
//     final icon = isOwed ? Icons.trending_down : owes ? Icons.trending_up : Icons.check_circle;
//     final label = isOwed ? 'You are owed' : owes ? 'You owe' : 'All settled';

//     return Card(
//       elevation: 0,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       color: Colors.grey.shade50,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left), style: IconButton.styleFrom(backgroundColor: Colors.white)),
//                 Text(DateFormat('MMMM yyyy').format(selectedMonth), style: const TextStyle(fontWeight: FontWeight.w500)),
//                 IconButton(onPressed: isCurrentMonth ? null : onNext, icon: const Icon(Icons.chevron_right), style: IconButton.styleFrom(backgroundColor: Colors.white)),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Icon(icon, size: 32, color: color),
//             const SizedBox(height: 8),
//             Text(label, style: TextStyle(color: Colors.grey.shade700)),
//             if (isOwed || owes)
//               Text('â‚¹${balance.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _MonthBalanceCard extends ConsumerWidget {
  final String monthKey;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthBalanceCard({required this.monthKey, required this.selectedMonth, required this.isCurrentMonth, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(monthOverallBalanceProvider(monthKey));
    final isOwed = balance > 0.01;
    final owes = balance < -0.01;
    final color = isOwed ? Colors.green : owes ? Colors.red : Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = LinearGradient(
      colors: isOwed
          ? (isDark ? [Colors.green.shade900.withOpacity(0.3), Colors.green.shade800.withOpacity(0.3)] : [Colors.green.shade50, Colors.green.shade100])
          : owes
              ? (isDark ? [Colors.red.shade900.withOpacity(0.3), Colors.red.shade800.withOpacity(0.3)] : [Colors.red.shade50, Colors.red.shade100])
              : (isDark ? [Colors.grey.shade900.withOpacity(0.3), Colors.grey.shade800.withOpacity(0.3)] : [Colors.grey.shade50, Colors.grey.shade100]),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final icon = isOwed ? Icons.arrow_downward_rounded : owes ? Icons.arrow_upward_rounded : Icons.check_circle_rounded;
    final label = isOwed ? 'You are owed' : owes ? 'You owe' : 'All settled';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: bgGradient),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: onPrev,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface, foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(selectedMonth),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      IconButton(
                        onPressed: isCurrentMonth ? null : onNext,
                        icon: const Icon(Icons.chevron_right, size: 20),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface, foregroundColor: isCurrentMonth ? Colors.grey : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Centered balance (icon and amount text aligned)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(icon, size: 32, color: color),
                            const SizedBox(width: 8),
                            if (isOwed || owes)
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: balance.abs()),
                                duration: const Duration(milliseconds: 600),
                                builder: (context, value, _) => Text(
                                  '\u20B9${value.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
                                ),
                              )
                            else
                              Text(
                                'Settled!',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Left decorative (no interference)
          Positioned(
            left: -25,
            bottom: 10,
            child: IgnorePointer(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.currency_rupee_rounded,
                  size: 45,
                  color: color.withOpacity(0.15),
                ),
              ),
            ),
          ),
          // Right watermark
          Positioned(
            bottom: -10,
            right: -10,
            child: IgnorePointer(
              child: Icon(
                Icons.currency_rupee_rounded,
                size: 60,
                color: color.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final String roomName;
  final int memberCount;
  final String inviteCode;
  final bool isAdmin;
  final VoidCallback onTap;
  const _RoomHeader({required this.roomName, required this.memberCount, required this.inviteCode, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.home_rounded, size: 22, color: cs.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomName, style: AppTextStyles.sectionHeader(context)),
                    const SizedBox(height: 2),
                    Text(
                      '$memberCount members â€¢ $inviteCode',
                      style: AppTextStyles.caption(context),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary)),
                ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendingSummary extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String userId;
  final String monthLabel;
  const _SpendingSummary({required this.expenses, required this.userId, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    final mySpent = expenses.where((e) => e.paidBy == userId).fold<double>(0, (s, e) => s + e.amount);
    final myPercentage = totalSpent > 0 ? (mySpent / totalSpent) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            // Total spent pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.group_rounded, size: 28, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700),
                    const SizedBox(height: 2),
                    Text(
                      '\u20B9${totalSpent.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Total spent', style: TextStyle(fontSize: 12, color: isDark ? Colors.blue.shade300 : Colors.blue.shade600)),
                        Text(' ($monthLabel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.blue.shade400 : Colors.blue.shade400)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Your spend pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_rounded, size: 28, color: isDark ? Colors.purple.shade300 : Colors.purple.shade700),
                    const SizedBox(height: 2),
                    Text(
                      '\u20B9${mySpent.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.purple.shade200 : Colors.purple.shade800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Your spend', style: TextStyle(fontSize: 12, color: isDark ? Colors.purple.shade300 : Colors.purple.shade600)),
                        Text(' ($monthLabel)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.purple.shade400 : Colors.purple.shade400)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Insight card below
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).colorScheme.surface : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your share of total',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  Text(
                    '${(myPercentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: myPercentage,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  color: myPercentage > 0.5 ? Colors.blue.shade400 : Colors.purple.shade400,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                myPercentage > 0.5
                    ? 'You paid most of the expenses this month'
                    : 'Others covered most of the expenses',
                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  final String roomId;
  final DateTime selectedMonth;
  final Future<bool> Function()? checkUpiExist;
  const _QuickActions({required this.roomId, required this.selectedMonth, this.checkUpiExist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              if (checkUpiExist != null && !await checkUpiExist!()) return;
              final room = ref.read(userRoomsProvider).valueOrNull?.first;
              if (room != null) ref.read(currentRoomProvider.notifier).state = room;
              showAddExpenseSheet(context, roomId: roomId, initialDate: selectedMonth);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              if (checkUpiExist != null && !await checkUpiExist!()) return;
              context.push('/room/$roomId?tab=settlements');
            },
            icon: const Icon(Icons.handshake),
            label: const Text('Settle Up'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _CategoryBreakdown({required this.expenses});
  static const _colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal, Colors.amber, Colors.pink];

  @override
  Widget build(BuildContext context) {
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    if (totalSpent == 0) return const SizedBox.shrink();

    final catTotals = <String, double>{};
    for (final e in expenses) catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    final entries = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pie chart (larger)
                SizedBox(
                  width: 100,
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                      sections: entries.asMap().entries.map((e) => PieChartSectionData(
                        value: e.value.value,
                        color: _colors[e.key % _colors.length],
                        title: '',
                        radius: 48,
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Category chips (wrap, flexible)
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: entries.map((e) => _CategoryChip(
                      label: e.key,
                      amount: e.value,
                      color: _colors[entries.indexOf(e) % _colors.length],
                    )).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _CategoryChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$label \u20B9${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(recentActivitiesProvider);
    if (activities.isEmpty) return const SizedBox.shrink();

    final recentActivities = activities.take(5).toList(); // Convert to List

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            ...recentActivities.asMap().entries.map((entry) {
              final index = entry.key;
              final a = entry.value;
              final isLast = index == recentActivities.length - 1;
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: _getIconColor(a.type).withOpacity(0.1),
                      child: Icon(_getIcon(a.type), size: 16, color: _getIconColor(a.type)),
                    ),
                    title: Text(
                      a.description,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatRelativeTime(a.createdAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  if (!isLast) const Divider(height: 1),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return Icons.add_circle_outline;
      case ActivityType.billAdded:
        return Icons.add_circle_outline;
      case ActivityType.expenseEdited:
        return Icons.edit_outlined;
      case ActivityType.billEdited:
        return Icons.edit_outlined;
      case ActivityType.expenseDeleted:
        return Icons.delete_outline;
      case ActivityType.billDeleted:
        return Icons.delete_outline;
      case ActivityType.settlementCreated:
        return Icons.payment_outlined;
      case ActivityType.settlementConfirmed:
        return Icons.check_circle_outline;
      case ActivityType.memberJoined:
        return Icons.person_add_outlined;
      case ActivityType.memberLeft:
        return Icons.person_remove_outlined;
      case ActivityType.roomCreated:
        return Icons.home_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(ActivityType type) {
    switch (type) {
      case ActivityType.expenseAdded:
        return Colors.green;
      case ActivityType.billAdded:
        return Colors.green;
      case ActivityType.expenseEdited:
        return Colors.orange;
      case ActivityType.billEdited:
        return Colors.orange;
      case ActivityType.expenseDeleted:
        return Colors.red;
      case ActivityType.billDeleted:
        return Colors.red;
      case ActivityType.settlementCreated:
        return Colors.blue;
      case ActivityType.settlementConfirmed:
        return Colors.teal;
      case ActivityType.memberJoined:
        return Colors.purple;
      case ActivityType.memberLeft:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('dd MMM').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _OnboardingTips extends ConsumerWidget {
  final String roomId;
  final String userId;
  const _OnboardingTips({required this.roomId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
    final recentActivities = ref.watch(recentActivitiesProvider);
    final tips = <_Tip>[];
    if (recentActivities.isEmpty) tips.add(_Tip(icon: Icons.receipt_long, text: 'Add your first expense', action: () => context.push('/room/$roomId/add-expense')));
    if (rooms.isNotEmpty && rooms.first.memberIds.length < 2) tips.add(_Tip(icon: Icons.person_add, text: 'Invite a roommate â€” share code: ${rooms.first.inviteCode}', action: null));
    if (profile != null && !profile.hasUpiId) tips.add(_Tip(icon: Icons.account_balance_wallet, text: 'Set up your UPI ID', action: null));
    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tips', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ...tips.map((t) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(t.icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(t.text, style: const TextStyle(fontSize: 12))),
            if (t.action != null) IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: t.action, padding: EdgeInsets.zero),
          ]),
        )),
      ],
    );
  }
}

class _Tip {
  final IconData icon;
  final String text;
  final VoidCallback? action;
  const _Tip({required this.icon, required this.text, this.action});
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.house_outlined,
      title: 'No room yet',
      subtitle: 'Create or join a room to get started',
      actionLabel: 'Create Room',
      onAction: () => context.push('/create-room'),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final String userName;
  final String userId;
  final bool isDeveloper;
  const _AppDrawer({required this.userName, required this.userId, required this.isDeveloper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
    final hasRoom = rooms.isNotEmpty;
    final firstRoom = hasRoom ? rooms.first : null;
    final isAdmin = firstRoom != null && firstRoom.isAdmin(userId);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: AppTextStyles.sectionHeader(context)),
                        Text('SplitEx', style: AppTextStyles.caption(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.divider(context), height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  if (hasRoom && isAdmin)
                    _DrawerTile(
                      icon: Icons.settings_outlined,
                      label: 'Room Settings',
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(currentRoomProvider.notifier).state = firstRoom!;
                        context.push('/room/${firstRoom.id}/settings');
                      },
                    ),
                  if (isDeveloper)
                    _DrawerTile(
                      icon: Icons.storage_outlined,
                      label: 'DB & Storage',
                      subtitle: 'Developer only',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/room/${firstRoom!.id}/storage');
                      },
                    ),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () { Navigator.pop(context); context.push('/notifications'); },
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () { Navigator.pop(context); context.push('/settings'); },
                  ),

                ],
              ),
            ),

            // Sign out at bottom
            Divider(color: AppColors.divider(context), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _DrawerTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                color: cs.error,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authServiceProvider).signOut();
                  ref.invalidate(currentRoomProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  const _DrawerTile({required this.icon, required this.label, this.subtitle, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      leading: Icon(icon, size: 20, color: effectiveColor.withValues(alpha: onTap != null ? 0.75 : 0.4)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onTap != null ? effectiveColor : effectiveColor.withValues(alpha: 0.4),
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption(context))
          : null,
      onTap: onTap,
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  static const _items = [
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Personal'),
    (icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Groups'),
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Room'),
    (icon: Icons.track_changes_outlined, activeIcon: Icons.track_changes_rounded, label: 'Tracker'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / _items.length;
            return Container(
              height: 66,
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHigh : cs.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.outline.withOpacity(isDark ? 0.15 : 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(isDark ? 0.15 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Sliding pill indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    left: itemWidth * selectedIndex + 8,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  // Nav items
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item = _items[i];
                      final selected = selectedIndex == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 66,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Glow dot above active icon
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  width: selected ? 4 : 0,
                                  height: selected ? 4 : 0,
                                  margin: EdgeInsets.only(bottom: selected ? 3 : 0),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: selected
                                        ? [BoxShadow(color: cs.primary.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)]
                                        : [],
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    selected ? item.activeIcon : item.icon,
                                    key: ValueKey(selected),
                                    size: 22,
                                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.4),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.4),
                                    letterSpacing: selected ? 0.2 : 0,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
