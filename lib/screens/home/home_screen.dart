import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/dashboard_provider.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/providers/theme_provider.dart';
import 'package:split_ex/screens/expense/add_expense_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() =>
      setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth =>
      _selectedMonth.year == DateTime.now().year &&
      _selectedMonth.month == DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(userRoomsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userName = profile?.name ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitEx'),
        actions: [
          _NotificationBell(),
        ],
      ),
      drawer: _AppDrawer(userName: userName, userId: userId),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rooms) {
          if (rooms.isEmpty) return _EmptyState();

          final room = rooms.first;
          final expensesAsync = ref.watch(monthExpensesProvider(
            MonthRoomKey(roomId: room.id, month: _monthKey),
          ));
          final expenses = expensesAsync.valueOrNull ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // 1. Greeting
              _GreetingHeader(
                userName: userName,
                selectedMonth: _selectedMonth,
              ),
              const SizedBox(height: 16),

              // 2. Month balance card
              _MonthBalanceCard(
                monthKey: _monthKey,
                selectedMonth: _selectedMonth,
                isCurrentMonth: _isCurrentMonth,
                onPrev: _prevMonth,
                onNext: _nextMonth,
              ),
              const SizedBox(height: 16),

              // 3. Room header
              _RoomHeader(
                roomName: room.name,
                memberCount: room.memberIds.length,
                inviteCode: room.inviteCode,
                isAdmin: room.isAdmin(userId),
                onTap: () {
                  ref.read(currentRoomProvider.notifier).state = room;
                  context.push('/room/${room.id}');
                },
              ),
              const SizedBox(height: 12),

              // 4. Category breakdown
              _CategoryBreakdown(expenses: expenses),
              const SizedBox(height: 16),

              // 5. Spending summary
              _SpendingSummary(
                expenses: expenses,
                userId: userId,
                monthLabel: DateFormat('MMM').format(_selectedMonth),
              ),
              const SizedBox(height: 16),

              // 6. Quick Actions
              _QuickActions(roomId: room.id, selectedMonth: _selectedMonth),
              const SizedBox(height: 16),

              // 7. Recent Activity
              _RecentActivitySection(),

              // 8. Tips
              _OnboardingTips(roomId: room.id, userId: userId),
            ],
          );
        },
      ),
    );
  }
}

// --- Drawer ---

class _AppDrawer extends ConsumerWidget {
  final String userName;
  final String userId;
  const _AppDrawer({required this.userName, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
    final hasRoom = rooms.isNotEmpty;

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
                  child: Text(userName[0].toUpperCase(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ),
                const SizedBox(height: 10),
                Text(userName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (hasRoom)
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Room Settings'),
              onTap: () {
                Navigator.pop(context);
                ref.read(currentRoomProvider.notifier).state = rooms.first;
                context.push('/room/${rooms.first.id}/settings');
              },
            ),
          if (hasRoom && rooms.first.isAdmin(userId))
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('DB & Storage'),
              subtitle: const Text('Admin only', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                context.push('/room/${rooms.first.id}/storage');
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Appearance',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const _DrawerThemeTile(),
          const _DrawerPaletteTile(),
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

class _DrawerThemeTile extends ConsumerWidget {
  const _DrawerThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final label = switch (themeMode) {
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
      AppThemeMode.deepDark => 'Deep Dark',
      AppThemeMode.system => 'System',
    };
    final icon = switch (themeMode) {
      AppThemeMode.light => Icons.light_mode,
      AppThemeMode.dark => Icons.dark_mode,
      AppThemeMode.deepDark => Icons.brightness_1,
      AppThemeMode.system => Icons.brightness_auto,
    };

    return ListTile(
      leading: Icon(icon),
      title: const Text('Theme'),
      subtitle: Text(label),
      onTap: () => _showThemeDialog(context, ref),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final themeMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: AppThemeMode.values.map((mode) {
          final modeLabel = switch (mode) {
            AppThemeMode.light => 'Light',
            AppThemeMode.dark => 'Dark',
            AppThemeMode.deepDark => 'Deep Dark',
            AppThemeMode.system => 'System',
          };
          final modeIcon = switch (mode) {
            AppThemeMode.light => Icons.light_mode,
            AppThemeMode.dark => Icons.dark_mode,
            AppThemeMode.deepDark => Icons.brightness_1,
            AppThemeMode.system => Icons.brightness_auto,
          };

          return RadioListTile<AppThemeMode>(
            value: mode,
            groupValue: themeMode,
            title: Text(modeLabel),
            secondary: Icon(modeIcon),
            onChanged: (value) {
              if (value == null) return;
              ref.read(themeModeProvider.notifier).setMode(value);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _DrawerPaletteTile extends ConsumerWidget {
  const _DrawerPaletteTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPalette = ref.watch(appPaletteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, size: 22),
              const SizedBox(width: 16),
              Text(
                'Color - ${AppTheme.paletteName(currentPalette)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppPalette.values.map((palette) {
              final isSelected = palette == currentPalette;
              final color = AppTheme.paletteColor(palette);

              return Tooltip(
                message: AppTheme.paletteName(palette),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => ref.read(appPaletteProvider.notifier).setPalette(palette),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// --- Greeting Header ---

class _GreetingHeader extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;

  const _GreetingHeader({required this.userName, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = selectedMonth.year == DateTime.now().year &&
        selectedMonth.month == DateTime.now().month;
    final monthStr = DateFormat('MMMM yyyy').format(selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $userName 👋',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              monthStr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isCurrentMonth
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: isCurrentMonth ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
            if (isCurrentMonth)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Current',
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ],
    );
  }
}

// --- Month Balance Card ---

class _MonthBalanceCard extends ConsumerWidget {
  final String monthKey;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthBalanceCard({
    required this.monthKey,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(monthOverallBalanceProvider(monthKey));
    final isOwed = balance > 0.01;
    final owes = balance < -0.01;
    final color = isOwed ? Colors.green : owes ? Colors.red : Colors.grey;
    final label = isOwed
        ? 'You are owed'
        : owes
            ? 'You owe'
            : 'All settled up!';
    final icon = isOwed
        ? Icons.trending_up
        : owes
            ? Icons.trending_down
            : Icons.check_circle_outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrev,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(selectedMonth),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrentMonth ? null : onNext,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            if (isOwed || owes)
              Text(
                '₹${balance.abs().toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Room Header ---

class _RoomHeader extends StatelessWidget {
  final String roomName;
  final int memberCount;
  final String inviteCode;
  final bool isAdmin;
  final VoidCallback onTap;

  const _RoomHeader({
    required this.roomName,
    required this.memberCount,
    required this.inviteCode,
    required this.isAdmin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                child: Text(roomName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomName, style: Theme.of(context).textTheme.titleMedium),
                    Text('$memberCount members • Code: $inviteCode',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (isAdmin) const Chip(label: Text('Admin')),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Spending Summary ---

class _SpendingSummary extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String userId;
  final String monthLabel;

  const _SpendingSummary({
    required this.expenses,
    required this.userId,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    final mySpent = expenses
        .where((e) => e.paidBy == userId)
        .fold<double>(0, (s, e) => s + e.amount);

    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            label: 'Total ($monthLabel)',
            value: '₹${totalSpent.toStringAsFixed(0)}',
            icon: Icons.group,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(
            label: 'My Spends ($monthLabel)',
            value: '₹${mySpent.toStringAsFixed(0)}',
            icon: Icons.person,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

// --- Quick Actions ---

class _QuickActions extends ConsumerWidget {
  final String roomId;
  final DateTime selectedMonth;
  const _QuickActions({required this.roomId, required this.selectedMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              final room = ref.read(userRoomsProvider).valueOrNull?.first;
              if (room != null) {
                ref.read(currentRoomProvider.notifier).state = room;
              }
              showAddExpenseSheet(context, roomId: roomId, initialDate: selectedMonth);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Expense'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/room/$roomId'),
            icon: const Icon(Icons.handshake, size: 18),
            label: const Text('Settle Up'),
          ),
        ),
      ],
    );
  }
}

// --- Category Breakdown ---

class _CategoryBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _CategoryBreakdown({required this.expenses});

  static const _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple,
    Colors.red, Colors.teal, Colors.amber, Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    if (totalSpent == 0) return const SizedBox.shrink();

    final catTotals = <String, double>{};
    for (final e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final catEntries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 1,
                    centerSpaceRadius: 16,
                    sections: catEntries.asMap().entries.map((e) {
                      return PieChartSectionData(
                        value: e.value.value,
                        color: _colors[e.key % _colors.length],
                        title: '',
                        radius: 26,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: catEntries.take(5).toList().asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, color: _colors[e.key % _colors.length]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${e.value.key} — ₹${e.value.value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Recent Activity Feed ---

class _RecentActivitySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(recentActivitiesProvider);
    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...activities.map((a) => _ActivityItem(activity: a)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final ActivityModel activity;
  const _ActivityItem({required this.activity});

  IconData get _icon => switch (activity.type) {
        ActivityType.expenseAdded => Icons.add_circle_outline,
        ActivityType.expenseEdited => Icons.edit,
        ActivityType.expenseDeleted => Icons.delete_outline,
        ActivityType.settlementCreated => Icons.payment,
        ActivityType.settlementConfirmed => Icons.check_circle_outline,
        ActivityType.memberJoined => Icons.person_add,
        ActivityType.memberLeft => Icons.person_remove,
        ActivityType.roomCreated => Icons.home_outlined,
        ActivityType.roomSettingsChanged => Icons.settings,
      };

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('dd MMM, hh:mm a').format(activity.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(activity.description,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(timeStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}

// --- Onboarding Tips ---

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

    if (recentActivities.isEmpty) {
      tips.add(_Tip(
        icon: Icons.receipt_long,
        text: 'Add your first expense',
        action: () => context.push('/room/$roomId/add-expense'),
      ));
    }

    if (rooms.isNotEmpty && rooms.first.memberIds.length < 2) {
      tips.add(_Tip(
        icon: Icons.person_add,
        text: 'Invite a roommate — share code: ${rooms.first.inviteCode}',
        action: null,
      ));
    }

    if (profile != null && !profile.hasUpiId) {
      tips.add(_Tip(
        icon: Icons.account_balance_wallet,
        text: 'Set up your UPI ID for easy settlements',
        action: null,
      ));
    }

    if (tips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Getting Started', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...tips.map((tip) => Card(
              child: ListTile(
                leading: Icon(tip.icon, color: Theme.of(context).colorScheme.primary),
                title: Text(tip.text, style: const TextStyle(fontSize: 13)),
                trailing: tip.action != null ? const Icon(Icons.chevron_right, size: 18) : null,
                onTap: tip.action,
                dense: true,
              ),
            )),
        const SizedBox(height: 80),
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

// --- Empty State ---

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No room yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Create or join a room to get started', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/create-room'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Room'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/join-room'),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Join Room'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared Widgets ---

class _MiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.notifications_none_rounded),
      ),
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
    );
  }
}
