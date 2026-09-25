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
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kBlue   = Color(0xFF3B82F6);
const _kAmber  = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);

// ---------------------------------------------------------------------------
// Public entry point — owns month state so home_screen stays untouched
// ---------------------------------------------------------------------------

class RoomTab extends ConsumerStatefulWidget {
  final Future<bool> Function() checkUpiExist;
  const RoomTab({super.key, required this.checkUpiExist});

  @override
  ConsumerState<RoomTab> createState() => _RoomTabState();
}

class _RoomTabState extends ConsumerState<RoomTab> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  bool get _isCurrentMonth =>
      _selectedMonth.year == DateTime.now().year &&
      _selectedMonth.month == DateTime.now().month;

  void _prevMonth() =>
      setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() {
    final now  = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(userRoomsProvider);
    final userId     = ref.watch(currentUserIdProvider);
    final profile    = ref.watch(userProfileProvider).valueOrNull;
    final userName   = profile?.name ?? 'User';

    return roomsAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rooms) {
        if (rooms.isEmpty) return _EmptyState();
        final room         = rooms.first;
        final expensesAsync = ref.watch(monthExpensesProvider(
          MonthRoomKey(roomId: room.id, month: _monthKey),
        ));
        final expenses = expensesAsync.valueOrNull ?? [];

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _Header(userName: userName, selectedMonth: _selectedMonth),
                const SizedBox(height: 20),
                _HeroCard(
                  monthKey: _monthKey,
                  selectedMonth: _selectedMonth,
                  isCurrentMonth: _isCurrentMonth,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                  expenses: expenses,
                  userId: userId,
                ),
                const SizedBox(height: 16),
                _MiniStats(expenses: expenses, userId: userId),
                const SizedBox(height: 20),
                _QuickActions(
                  roomId: room.id,
                  selectedMonth: _selectedMonth,
                  checkUpiExist: widget.checkUpiExist,
                  onOpenRoom: () async {
                    final allowed = await widget.checkUpiExist();
                    if (!allowed) return;
                    ref.read(currentRoomProvider.notifier).state = room;
                    if (context.mounted) context.push('/room/${room.id}', extra: _selectedMonth);
                  },
                ),
                const SizedBox(height: 20),
                _RoomCard(
                  room: room,
                  userId: userId,
                  onTap: () async {
                    final allowed = await widget.checkUpiExist();
                    if (!allowed) return;
                    ref.read(currentRoomProvider.notifier).state = room;
                    if (context.mounted) context.push('/room/${room.id}', extra: _selectedMonth);
                  },
                ),
                if (expenses.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _CategoryBreakdown(expenses: expenses),
                ],
                const SizedBox(height: 20),
                _SpendingSummary(
                  expenses: expenses,
                  userId: userId,
                  monthLabel: DateFormat('MMM').format(_selectedMonth),
                ),
                if (_isCurrentMonth) ...[
                  const SizedBox(height: 20),
                  _RecentActivity(roomId: room.id),
                ],
                const SizedBox(height: 16),
                _OnboardingTips(roomId: room.id, userId: userId),
                const SizedBox(height: 40),
              ],
            ),
            Positioned(
              bottom: 16, right: 16,
              child: FloatingActionButton(
                onPressed: () async {
                  if (!await widget.checkUpiExist()) return;
                  final r = ref.read(userRoomsProvider).valueOrNull?.first;
                  if (r != null) ref.read(currentRoomProvider.notifier).state = r;
                  if (context.mounted) {
                    showAddExpenseSheet(context, roomId: room.id, initialDate: _selectedMonth);
                  }
                },
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoading() => ListView.builder(
    padding: const EdgeInsets.all(AppSpacing.base),
    itemCount: 5,
    itemBuilder: (_, i) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: i == 0
          ? AppLoadingShimmer.block(height: 200)
          : AppLoadingShimmer.block(height: 72),
    ),
  );
}

// ---------------------------------------------------------------------------
// _Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String userName;
  final DateTime selectedMonth;
  const _Header({required this.userName, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $userName 👋',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('MMMM yyyy').format(selectedMonth),
          style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _HeroCard — modern gradient hero with month nav + balance + spend progress
// ---------------------------------------------------------------------------

class _HeroCard extends ConsumerWidget {
  final String monthKey;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final List<ExpenseModel> expenses;
  final String userId;
  const _HeroCard({
    required this.monthKey,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.expenses,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final balance    = ref.watch(monthOverallBalanceProvider(monthKey));
    final isOwed     = balance > 0.01;
    final owes       = balance < -0.01;
    final isSettled  = !isOwed && !owes;

    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    final mySpent    = expenses.where((e) => e.paidBy == userId).fold<double>(0, (s, e) => s + e.amount);
    final spendRatio = totalSpent > 0 ? (mySpent / totalSpent).clamp(0.0, 1.0) : 0.0;

    final gradientColors = isOwed
        ? (isDark ? [const Color(0xFF064E3B), const Color(0xFF065F46)] : [const Color(0xFF059669), const Color(0xFF0D9488)])
        : owes
            ? (isDark ? [const Color(0xFF7F1D1D), const Color(0xFF831843)] : [const Color(0xFFDC2626), const Color(0xFFDB2777)])
            : (isDark ? [const Color(0xFF064E3B), const Color(0xFF065F46)] : [const Color(0xFF059669), const Color(0xFF0D9488)]);

    final onCard      = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.85);

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
                  // Month nav row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavBtn(onTap: onPrev, icon: Icons.chevron_left, onCard: onCard),
                      Column(
                        children: [
                          Text(DateFormat('MMMM yyyy').format(selectedMonth),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: onCard)),
                          if (isCurrentMonth)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                              child: Text('Current Month', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: onCard, letterSpacing: 0.4)),
                            ),
                        ],
                      ),
                      _NavBtn(onTap: isCurrentMonth ? null : onNext, icon: Icons.chevron_right, onCard: onCard),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Balance label
                  Text(
                    isSettled ? 'Net Balance' : isOwed ? "You're Owed" : 'You Owe',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onCardMuted, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 6),
                  // Animated balance amount
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: balance.abs()),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text(
                      isSettled ? '₹0' : '₹${v.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1.5, height: 1.1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Chips row
                  Row(
                    children: [
                      AppHeroChip(icon: Icons.receipt_long_rounded, label: 'Spent', value: '₹${totalSpent.toStringAsFixed(0)}', onCard: onCard, onCardMuted: onCardMuted),
                      const SizedBox(width: 10),
                      AppHeroChip(icon: Icons.person_rounded, label: 'Mine', value: '₹${mySpent.toStringAsFixed(0)}', onCard: onCard, onCardMuted: onCardMuted),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isSettled ? Icons.check_circle_rounded : isOwed ? Icons.south_rounded : Icons.north_rounded, size: 16, color: onCard),
                          const SizedBox(height: 2),
                          Text(isSettled ? '✓' : isOwed ? '+' : '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard)),
                          Text('net', style: TextStyle(fontSize: 9, color: onCardMuted)),
                        ]),
                      ),
                    ],
                  ),
                  if (totalSpent > 0) ...[
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your share of total', style: TextStyle(fontSize: 10, color: onCardMuted)),
                        Text('${(spendRatio * 100).toInt()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: onCard)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: spendRatio,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          spendRatio > 0.8
                              ? const Color(0xFFFCA5A5)
                              : spendRatio > 0.5
                                  ? const Color(0xFFFDE68A)
                                  : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color onCard;
  const _NavBtn({required this.onTap, required this.icon, required this.onCard});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: onCard.withValues(alpha: enabled ? 0.9 : 0.3)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MiniStats
// ---------------------------------------------------------------------------

class _MiniStats extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String userId;
  const _MiniStats({required this.expenses, required this.userId});

  @override
  Widget build(BuildContext context) {
    final total   = expenses.fold<double>(0, (s, e) => s + e.amount);
    final mine    = expenses.where((e) => e.paidBy == userId).fold<double>(0, (s, e) => s + e.amount);
    final others  = total - mine;
    return Row(
      children: [
        Expanded(child: AppMiniStatCard(label: 'Total Spent', value: '₹${total.toStringAsFixed(0)}', icon: Icons.receipt_long_rounded, color: _kBlue)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'You Paid',    value: '₹${mine.toStringAsFixed(0)}',  icon: Icons.person_rounded,        color: _kGreen)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Others Paid', value: '₹${others.toStringAsFixed(0)}', icon: Icons.people_rounded,       color: _kIndigo)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _QuickActions — preserves original onTap callbacks exactly
// ---------------------------------------------------------------------------

class _QuickActions extends ConsumerWidget {
  final String roomId;
  final DateTime selectedMonth;
  final Future<bool> Function() checkUpiExist;
  final VoidCallback onOpenRoom;
  const _QuickActions({
    required this.roomId,
    required this.selectedMonth,
    required this.checkUpiExist,
    required this.onOpenRoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QA(
        icon: Icons.add_circle_outline_rounded,
        label: 'Add',
        color: _kGreen,
        onTap: () async {
          if (!await checkUpiExist()) return;
          final room = ref.read(userRoomsProvider).valueOrNull?.first;
          if (room != null) ref.read(currentRoomProvider.notifier).state = room;
          if (context.mounted) showAddExpenseSheet(context, roomId: roomId, initialDate: selectedMonth);
        },
      ),
      _QA(
        icon: Icons.handshake_outlined,
        label: 'Settle',
        color: _kTeal,
        onTap: () async {
          if (!await checkUpiExist()) return;
          if (context.mounted) context.push('/room/$roomId?tab=settlements');
        },
      ),
      _QA(icon: Icons.home_rounded,    label: 'Room',    color: _kBlue,   onTap: onOpenRoom),
      _QA(icon: Icons.history_rounded, label: 'Activity',color: _kIndigo, onTap: () => context.push('/room/$roomId/activity')),
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => actions[i],
      ),
    );
  }
}

class _QA extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3), width: 1.5),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RoomCard — tapping navigates to room detail (original behavior)
// ---------------------------------------------------------------------------

class _RoomCard extends StatelessWidget {
  final dynamic room;
  final String userId;
  final VoidCallback onTap;
  const _RoomCard({required this.room, required this.userId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = room.isAdmin(userId) as bool;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: appCardDecoration(context, accentColor: _kBlue),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 3,
                decoration: const BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(AppRadius.xl),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        (room.name as String)[0].toUpperCase(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name as String,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.people_outline_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text('${(room.memberIds as List).length} members',
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 3, height: 3,
                            decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.25), shape: BoxShape.circle),
                          ),
                          Icon(Icons.vpn_key_outlined, size: 11, color: cs.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text(room.inviteCode as String,
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (room.isLocked as bool)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kAmber.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kAmber.withValues(alpha: 0.25)),
                      ),
                      child: const Text('Locked', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kAmber)),
                    )
                  else if (isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
                      ),
                      child: const Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kBlue)),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategoryBreakdown — pie chart + chips (original logic, modern card shell)
// ---------------------------------------------------------------------------

class _CategoryBreakdown extends StatelessWidget {
  final List<ExpenseModel> expenses;
  const _CategoryBreakdown({required this.expenses});

  static const _colors = [_kBlue, _kGreen, _kAmber, _kPurple, _kRed, _kTeal, _kIndigo, Color(0xFFEC4899)];

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final total   = expenses.fold<double>(0, (s, e) => s + e.amount);
    if (total == 0) return const SizedBox.shrink();

    final catTotals = <String, double>{};
    for (final e in expenses) catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    final entries = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Spending Breakdown', actionLabel: null, onAction: null),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110, height: 110,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 28,
                  sections: entries.asMap().entries.map((e) => PieChartSectionData(
                    value: e.value.value,
                    color: _colors[e.key % _colors.length],
                    title: '',
                    radius: 36,
                  )).toList(),
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8, runSpacing: 6,
                  children: entries.map((e) {
                    final idx   = entries.indexOf(e);
                    final color = _colors[idx % _colors.length];
                    final pct   = (e.value / total * 100).toInt();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('${e.key} $pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SpendingSummary — original logic, modern card shell
// ---------------------------------------------------------------------------

class _SpendingSummary extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String userId;
  final String monthLabel;
  const _SpendingSummary({required this.expenses, required this.userId, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final cs           = Theme.of(context).colorScheme;
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final totalSpent   = expenses.fold<double>(0, (s, e) => s + e.amount);
    final mySpent      = expenses.where((e) => e.paidBy == userId).fold<double>(0, (s, e) => s + e.amount);
    final myPercentage = totalSpent > 0 ? (mySpent / totalSpent) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Spending Summary', actionLabel: null, onAction: null),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Total ($monthLabel)', value: '₹${totalSpent.toStringAsFixed(0)}', icon: Icons.group_rounded,  color: _kBlue,   isDark: isDark, cs: cs)),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'You ($monthLabel)',   value: '₹${mySpent.toStringAsFixed(0)}',   icon: Icons.person_rounded, color: _kPurple, isDark: isDark, cs: cs)),
            ],
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Your share of total', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
            Text('${(myPercentage * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: myPercentage,
              minHeight: 7,
              backgroundColor: cs.outline.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(myPercentage > 0.5 ? _kBlue : _kPurple),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            myPercentage > 0.5 ? 'You paid most of the expenses this month' : 'Others covered most of the expenses',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ])),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// _RecentActivity — original logic, modern card shell
// ---------------------------------------------------------------------------

class _RecentActivity extends ConsumerWidget {
  final String roomId;
  const _RecentActivity({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs         = Theme.of(context).colorScheme;
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final activities = ref.watch(recentActivitiesProvider).take(5).toList();

    if (activities.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: () => context.push('/room/$roomId/activity'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.lg),
                  ),
                  child: Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...activities.asMap().entries.map((entry) {
            final a      = entry.value;
            final isLast = entry.key == activities.length - 1;
            final accent = _activityColor(a.type);
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.07 : 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                    child: Icon(_activityIcon(a.type), size: 17, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.description,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_relativeTime(a.createdAt),
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                  ])),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _activityIcon(ActivityType t) => switch (t) {
    ActivityType.expenseAdded        => Icons.add_circle_outline_rounded,
    ActivityType.expenseEdited       => Icons.edit_outlined,
    ActivityType.expenseDeleted      => Icons.delete_outline_rounded,
    ActivityType.billAdded           => Icons.receipt_outlined,
    ActivityType.billEdited          => Icons.edit_note_rounded,
    ActivityType.billDeleted         => Icons.delete_outline_rounded,
    ActivityType.settlementCreated   => Icons.handshake_outlined,
    ActivityType.settlementConfirmed => Icons.check_circle_outline_rounded,
    ActivityType.memberJoined        => Icons.person_add_outlined,
    ActivityType.memberLeft          => Icons.person_remove_outlined,
    ActivityType.roomCreated         => Icons.home_outlined,
    ActivityType.roomSettingsChanged => Icons.settings_outlined,
  };

  Color _activityColor(ActivityType t) => switch (t) {
    ActivityType.expenseAdded        => _kBlue,
    ActivityType.expenseEdited       => _kIndigo,
    ActivityType.expenseDeleted      => _kRed,
    ActivityType.billAdded           => _kTeal,
    ActivityType.billEdited          => _kTeal,
    ActivityType.billDeleted         => _kRed,
    ActivityType.settlementCreated   => _kAmber,
    ActivityType.settlementConfirmed => _kGreen,
    ActivityType.memberJoined        => _kGreen,
    ActivityType.memberLeft          => _kAmber,
    ActivityType.roomCreated         => _kBlue,
    ActivityType.roomSettingsChanged => _kPurple,
  };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7)    return DateFormat('dd MMM').format(dt);
    if (diff.inDays > 0)    return '${diff.inDays}d ago';
    if (diff.inHours > 0)   return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

// ---------------------------------------------------------------------------
// _OnboardingTips — original logic preserved exactly
// ---------------------------------------------------------------------------

class _OnboardingTips extends ConsumerWidget {
  final String roomId;
  final String userId;
  const _OnboardingTips({required this.roomId, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile          = ref.watch(userProfileProvider).valueOrNull;
    final rooms            = ref.watch(userRoomsProvider).valueOrNull ?? [];
    final recentActivities = ref.watch(recentActivitiesProvider);
    final tips             = <_Tip>[];

    if (recentActivities.isEmpty) {
      tips.add(_Tip(icon: Icons.receipt_long, text: 'Add your first expense',
          action: () => context.push('/room/$roomId/add-expense')));
    }
    if (rooms.isNotEmpty && rooms.first.memberIds.length < 2) {
      tips.add(_Tip(icon: Icons.person_add,
          text: 'Invite a roommate — share code: ${rooms.first.inviteCode}', action: null));
    }
    if (profile != null && !profile.hasUpiId) {
      tips.add(_Tip(icon: Icons.account_balance_wallet, text: 'Set up your UPI ID', action: null));
    }
    if (tips.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: 'Tips', actionLabel: null, onAction: null),
        const SizedBox(height: 10),
        ...tips.map((t) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(t.icon, size: 16, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(t.text, style: const TextStyle(fontSize: 12))),
            if (t.action != null)
              IconButton(icon: const Icon(Icons.chevron_right, size: 18), onPressed: t.action, padding: EdgeInsets.zero),
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

// ---------------------------------------------------------------------------
// _EmptyState — original behavior preserved
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
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
