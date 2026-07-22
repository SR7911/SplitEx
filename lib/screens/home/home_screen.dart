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
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/expense/add_expense_sheet.dart';
import 'package:split_ex/screens/groups/groups_list_screen.dart';
import 'package:split_ex/screens/personal/personal_expense_tab.dart';
import 'package:split_ex/screens/projects/projects_list_screen.dart';
import 'package:split_ex/services/recurring_processor.dart';
import 'package:split_ex/services/user_service.dart';
import 'package:split_ex/screens/settlement/upi_id_dialog.dart';
import 'package:split_ex/widgets/offline_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late DateTime _selectedMonth;
  late AnimationController _animationController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
    _tabController = TabController(length: 4, vsync: this);
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
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() {
        _selectedMonth = next;
        _animationController.reset();
        _animationController.forward();
      });
    }
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
    final roomsAsync = ref.watch(userRoomsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final isDeveloper = ref.watch(isDeveloperProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userName = profile?.name ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitEx', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: const [OfflineIndicator(), _NotificationBell()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.home_rounded, size: 20), text: 'Room'),
            Tab(icon: Icon(Icons.groups_rounded, size: 20), text: 'Groups'),
            Tab(icon: Icon(Icons.construction_rounded, size: 20), text: 'Projects'),
            Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 20), text: 'My Expenses'),
          ],
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      drawer: _AppDrawer(userName: userName, userId: userId, isDeveloper: isDeveloper),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Room Expenses (existing)
          FadeTransition(
            opacity: _animationController,
            child: roomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rooms) {
                if (rooms.isEmpty) return const _EmptyState();
                final room = rooms.first;
                final expensesAsync = ref.watch(monthExpensesProvider(
                  MonthRoomKey(roomId: room.id, month: _monthKey),
                ));
                final expenses = expensesAsync.valueOrNull ?? [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _GreetingHeader(userName: userName, selectedMonth: _selectedMonth),
                    const SizedBox(height: 20),
                    _MonthBalanceCard(
                      monthKey: _monthKey,
                      selectedMonth: _selectedMonth,
                      isCurrentMonth: _isCurrentMonth,
                      onPrev: _prevMonth,
                      onNext: _nextMonth,
                    ),
                    const SizedBox(height: 20),
                    _RoomHeader(
                      roomName: room.name,
                      memberCount: room.memberIds.length,
                      inviteCode: room.inviteCode,
                      isAdmin: room.isAdmin(userId),
                      onTap: () async {
                        final allowed = await checkUpiExist();
                        if (!allowed) return;
                        ref.read(currentRoomProvider.notifier).state = room;
                        context.push('/room/${room.id}', extra: _selectedMonth);
                      },
                    ),
                    const SizedBox(height: 20),
                    if (expenses.isNotEmpty) _CategoryBreakdown(expenses: expenses),
                    if (expenses.isNotEmpty) const SizedBox(height: 20),
                    _SpendingSummary(
                      expenses: expenses,
                      userId: userId,
                      monthLabel: DateFormat('MMM').format(_selectedMonth),
                    ),
                    const SizedBox(height: 20),
                    _QuickActions(roomId: room.id, selectedMonth: _selectedMonth, checkUpiExist: checkUpiExist),
                    if (_isCurrentMonth) ...[
                      const SizedBox(height: 20),
                      _RecentActivitySection(),
                    ],
                    const SizedBox(height: 16),
                    _OnboardingTips(roomId: room.id, userId: userId),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),

          // Tab 2: Groups
          const GroupsListScreen(),

          // Tab 3: Projects
          const ProjectsListScreen(),

          // Tab 4: Personal Expenses (separate module)
          const PersonalExpenseTab(),
        ],
      ),
    );
  }
}

// ==========================
// Refined Sub‑widgets
// ==========================

class _GreetingHeader extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;
  const _GreetingHeader({required this.userName, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final isCurrent = selectedMonth.year == DateTime.now().year && selectedMonth.month == DateTime.now().month;
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, $userName 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(monthStr, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600)),
            if (isCurrent)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
              ),
          ],
        ),
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
//               Text('₹${balance.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
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
                                  '₹${value.toStringAsFixed(0)}',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Icon(Icons.home_rounded, size: 24, color: Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('$memberCount members • Code: $inviteCode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('Admin', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
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
                      '₹${totalSpent.toStringAsFixed(0)}',
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
                      '₹${mySpent.toStringAsFixed(0)}',
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
            '$label ₹${amount.toStringAsFixed(0)}',
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
    if (rooms.isNotEmpty && rooms.first.memberIds.length < 2) tips.add(_Tip(icon: Icons.person_add, text: 'Invite a roommate — share code: ${rooms.first.inviteCode}', action: null));
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.house_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No room yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Create or join a room to get started', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: () => context.push('/create-room'), icon: const Icon(Icons.add), label: const Text('Create Room')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => context.push('/join-room'), icon: const Icon(Icons.person_add), label: const Text('Join Room')),
        ]),
      ),
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
    final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
    final hasRoom = rooms.isNotEmpty;
    final firstRoom = hasRoom ? rooms.first : null;
    final isAdmin = firstRoom != null && firstRoom.isAdmin(userId);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    userName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (hasRoom && isAdmin)
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Room Settings'),
              onTap: () {
                Navigator.pop(context);
                ref.read(currentRoomProvider.notifier).state = firstRoom!;
                context.push('/room/${firstRoom.id}/settings');
              },
            ),
          if (isDeveloper)
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('DB & Storage'),
              subtitle: const Text('Developer only', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                context.push('/room/${firstRoom!.id}/storage');
              },
            ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () {
              Navigator.pop(context);
              context.push('/notifications');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.group_add, color: Colors.grey[400]),
            title: Text('Create Room', style: TextStyle(color: Colors.grey[400])),
            subtitle: const Text('Coming soon', style: TextStyle(fontSize: 11)),
            onTap: null,
          ),
          ListTile(
            leading: Icon(Icons.person_add, color: Colors.grey[400]),
            title: Text('Join Room', style: TextStyle(color: Colors.grey[400])),
            subtitle: const Text('Coming soon', style: TextStyle(fontSize: 11)),
            onTap: null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(currentRoomProvider);
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;
    return IconButton(
      icon: Badge(isLabelVisible: count > 0, label: Text('$count', style: const TextStyle(fontSize: 10)), child: const Icon(Icons.notifications_none_rounded)),
      onPressed: () => context.push('/notifications'),
    );
  }
}