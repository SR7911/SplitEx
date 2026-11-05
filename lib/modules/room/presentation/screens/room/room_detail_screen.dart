import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/dependencies.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/presentation/config/room_constants.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/presentation/providers/bill_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/dashboard_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/expense_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/modules/room/presentation/screens/expense/add_expense_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/expense/view_expense_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/bills/add_bill_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/bills/view_bill_sheet.dart';
import 'package:split_ex/modules/room/presentation/screens/room/pair_settlement_card.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/settlement_provider.dart';

// -- Shared design tokens --
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);
const _kBlue = Color(0xFF3B82F6);
const _kTeal = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);
const _kPalette = [_kBlue, _kGreen, _kAmber, _kIndigo, _kTeal, _kPurple, _kRed];

BoxDecoration _cardDeco(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
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

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  final DateTime selectedMonthInHome;
  final int initialTabIndex;
  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.selectedMonthInHome,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedMonth = widget.selectedMonthInHome;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() => setState(() {}));
    // _selectedMonth = widget.selectedMonthInHome;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
  });

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _selectedMonth = next);
    }
  }

  void _showAnalyticsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, controller) => _AnalyticsSheet(
          roomId: widget.roomId,
          monthKey: _monthKey,
          scrollController: controller,
        ),
      ),
    );
  }

  Future<void> _generateReceipt(BuildContext context, WidgetRef ref) async {
    final receiptMonth = _monthKey;
    final room = await ref.read(roomStreamProvider(widget.roomId).future);
    if (room == null) return;
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating receipt...')));

    final expenses = await ref.read(
      monthExpensesProvider(
        MonthRoomKey(roomId: widget.roomId, month: receiptMonth),
      ).future,
    );

    final bills = await ref.read(
      billsStreamProvider(
        MonthBillKey(roomId: widget.roomId, month: receiptMonth),
      ).future,
    );

    final settlements = await ref.read(
      settlementsStreamProvider(widget.roomId).future,
    );
    final participantIds = ref.read(
      monthParticipantIdsProvider(
        MonthBalanceKey(roomId: widget.roomId, month: receiptMonth),
      ),
    );

    final debts = ref.read(
      monthPairDebtsProvider(
        MonthBalanceKey(roomId: widget.roomId, month: receiptMonth),
      ),
    );
    final detailedMap = ref.read(
      detailedDebtsMapProvider(
        MonthBalanceKey(roomId: widget.roomId, month: receiptMonth),
      ),
    );

    final members = await ref.read(
      userProfilesByIdsProvider(participantIds).future,
    );
    final nameMap = <String, String>{};
    {
      for (final m in members) {
        nameMap[m.uid] = m.name;
      }
    }

    final generator = ref.read(roomReceiptExporterProvider);
    final filePath = await generator.generateMonthlyReceiptPath(
      roomName: room.name,
      month: receiptMonth,
      expenses: expenses,
      bills: bills,
      nameMap: nameMap,
      debts: debts,
      memberCount: participantIds.length,
      detailedDebtsMap: detailedMap,
      memberIds: participantIds,
      settlements: settlements
          .where((s) => s.effectiveMonth == receiptMonth)
          .toList(),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await generator.sharePdfPath(
      filePath,
      text: 'SplitEx Monthly Receipt - ${room.name} ($receiptMonth)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final room = roomAsync.valueOrNull;
    final userId = ref.watch(currentUserIdProvider);
    if (roomAsync.isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (roomAsync.hasError || room == null || !room.canRead(userId)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room')),
        body: const Center(child: Text('Unable to load this room.')),
      );
    }

    return Scaffold(
      appBar: _GradientTabAppBar(
        title: room.name,
        tabController: _tabController,
        onAnalytics: () => _showAnalyticsSheet(context),
        onReceipt: () async {
          try {
            await _generateReceipt(context, ref);
          } catch (e) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to export receipt: $e')),
              );
          }
        },
        onActivity: () => context.push('/room/${widget.roomId}/activity'),
        onSettings: () => context.push('/room/${widget.roomId}/settings'),
      ),
      body: GradientBody(
        child: Column(
          children: [
            if (room.isArchived || !room.isMember(userId))
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  room.isArchived
                      ? 'Archived room · history preserved. Restore in Room Settings to make changes.'
                      : 'Former member · your history and outstanding balances are preserved.',
                ),
              ),
            _MonthSelector(
              month: _selectedMonth,
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ExpensesTab(roomId: widget.roomId, month: _monthKey),
                  _BillsTab(roomId: widget.roomId, month: _monthKey),
                  _SettlementsTab(roomId: widget.roomId, month: _monthKey),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2 || !room.canWrite(userId)
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  showAddExpenseSheet(
                    context,
                    roomId: widget.roomId,
                    initialDate: _selectedMonth,
                  );
                } else if (_tabController.index == 1) {
                  showAddBillSheet(
                    context,
                    roomId: widget.roomId,
                    initialDate: _selectedMonth,
                  );
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

// ========== GRADIENT TAB APP BAR ==========
class _GradientTabAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final TabController tabController;
  final VoidCallback onAnalytics;
  final VoidCallback onReceipt;
  final VoidCallback onActivity;
  final VoidCallback onSettings;

  const _GradientTabAppBar({
    required this.title,
    required this.tabController,
    required this.onAnalytics,
    required this.onReceipt,
    required this.onActivity,
    required this.onSettings,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 1.0],
          colors: [
            cs.primary.withValues(alpha: isDark ? 0.55 : 0.45),
            cs.primary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Analytics',
            onPressed: onAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Generate Receipt',
            onPressed: onReceipt,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity Log',
            onPressed: onActivity,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Room Settings',
            onPressed: onSettings,
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Bills'),
            Tab(text: 'Settlements'),
          ],
        ),
      ),
    );
  }
}

// ========== ANALYTICS BOTTOM SHEET ==========
String _fmt(double v) => '₹${NumberFormat('#,##0', 'en_IN').format(v.round())}';

class _AnalyticsSheet extends ConsumerWidget {
  final String roomId;
  final String monthKey;
  final ScrollController scrollController;

  const _AnalyticsSheet({
    required this.roomId,
    required this.monthKey,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses =
        ref
            .watch(
              monthExpensesProvider(
                MonthRoomKey(roomId: roomId, month: monthKey),
              ),
            )
            .valueOrNull ??
        [];
    final bills =
        ref
            .watch(
              billsStreamProvider(
                MonthBillKey(roomId: roomId, month: monthKey),
              ),
            )
            .valueOrNull ??
        [];
    final expTotal = expenses.fold<double>(0, (s, e) => s + e.amount);
    final billTotal = bills.fold<double>(0, (s, e) => s + e.amount);
    final total = expTotal + billTotal;

    if (expenses.isEmpty && bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No data this month',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final catTotals = <String, double>{};
    for (final e in expenses)
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    for (final e in bills)
      catTotals[e.typeName] = (catTotals[e.typeName] ?? 0) + e.amount;
    final catEntries = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dailyTotals = <int, double>{};
    for (final e in expenses)
      dailyTotals[e.date.day] = (dailyTotals[e.date.day] ?? 0) + e.amount;
    for (final e in bills)
      dailyTotals[e.date.day] = (dailyTotals[e.date.day] ?? 0) + e.amount;
    final days = dailyTotals.keys.toList()..sort();
    final maxY = dailyTotals.values.fold<double>(0, (a, b) => a > b ? a : b);

    final memberTotals = <String, double>{};
    for (final e in expenses)
      memberTotals[e.paidBy] = (memberTotals[e.paidBy] ?? 0) + e.amount;
    for (final e in bills)
      memberTotals[e.paidBy] = (memberTotals[e.paidBy] ?? 0) + e.amount;
    final membersSorted = memberTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final members = ref.watch(
      monthParticipantIdsProvider(
        MonthBalanceKey(roomId: roomId, month: monthKey),
      ),
    );
    final membersAsync = ref.watch(userProfilesByIdsProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Title
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: _kIndigo,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Analytics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              monthKey,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Stats banner
        Container(
          decoration: _cardDeco(context),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              _StatCell(label: 'Expenses', value: _fmt(expTotal), color: _kRed),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cs.outline.withValues(alpha: 0.12),
              ),
              _StatCell(label: 'Bills', value: _fmt(billTotal), color: _kAmber),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cs.outline.withValues(alpha: 0.12),
              ),
              _StatCell(label: 'Total', value: _fmt(total), color: _kIndigo),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Categories
        _SectionHeader(label: 'Categories', color: _kBlue),
        const SizedBox(height: 10),
        Container(
          decoration: _cardDeco(context),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: catEntries
                            .asMap()
                            .entries
                            .map(
                              (e) => PieChartSectionData(
                                value: e.value.value,
                                color: _kPalette[e.key % _kPalette.length],
                                title: '',
                                radius: 22,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Text(
                      _fmt(total),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: catEntries.take(6).map((entry) {
                    final idx = catEntries.indexOf(entry);
                    final pct = total > 0
                        ? (entry.value / total * 100).round()
                        : 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _kPalette[idx % _kPalette.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _kPalette[idx % _kPalette.length]
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$pct%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _kPalette[idx % _kPalette.length],
                              ),
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
        const SizedBox(height: 8),
        // Category bars
        ...catEntries.map((entry) {
          final idx = catEntries.indexOf(entry);
          final color = _kPalette[idx % _kPalette.length];
          final pct = total > 0 ? entry.value / total : 0.0;
          return Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: _cardDeco(context),
            child: Row(
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              _fmt(entry.value),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.toDouble(),
                            minHeight: 4,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        // Daily spending
        if (days.isNotEmpty) ...[
          _SectionHeader(label: 'Daily Spending', color: _kTeal),
          const SizedBox(height: 10),
          Container(
            decoration: _cardDeco(context),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.25,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: days
                      .map(
                        (day) => BarChartGroupData(
                          x: day,
                          barRods: [
                            BarChartRodData(
                              toY: dailyTotals[day]!,
                              width: 10,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              color: _kTeal,
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Who paid
        if (membersSorted.isNotEmpty) ...[
          _SectionHeader(label: 'Who Paid', color: _kPurple),
          const SizedBox(height: 10),
          ...membersSorted.map((entry) {
            final name = nameMap[entry.key] ?? entry.key;
            final pct = total > 0 ? entry.value / total : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: _cardDeco(context),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _kPurple,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _kPurple.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: const AlwaysStoppedAnimation(_kPurple),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmt(entry.value),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kPurple,
                          ),
                        ),
                        Text(
                          '${(pct * 100).round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ========== MONTH SELECTOR ==========
class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthSelector({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth =
        month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const onCard = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    cs.primary.withValues(alpha: 0.55),
                    cs.primary.withValues(alpha: 0.35),
                  ]
                : [
                    cs.primary.withValues(alpha: 0.85),
                    cs.primary.withValues(alpha: 0.65),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavBtn(onTap: onPrev, icon: Icons.chevron_left),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: onCard,
                  ),
                ),
                if (isCurrentMonth) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Current Month',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: onCard,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy').format(month),
                    style: TextStyle(fontSize: 10, color: onCardMuted),
                  ),
                ],
              ],
            ),
            _NavBtn(
              onTap: isCurrentMonth ? null : onNext,
              icon: Icons.chevron_right,
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
  const _NavBtn({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.3),
        ),
      ),
    );
  }
}

// ========== FILTER/SORT ==========
enum _SortOption { timeDesc, timeAsc, amountDesc, amountAsc }

// ========== EXPENSES TAB ==========
class _ExpensesTab extends ConsumerStatefulWidget {
  final String roomId;
  final String month;
  const _ExpensesTab({required this.roomId, required this.month});

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  String? _filterUser;
  String? _filterCategory;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  _SortOption _sortOption = _SortOption.timeDesc;

  bool get _hasActiveFilters =>
      _filterUser != null ||
      _filterCategory != null ||
      _filterDateFrom != null ||
      _filterDateTo != null;

  void _clearFilters() => setState(() {
    _filterUser = null;
    _filterCategory = null;
    _filterDateFrom = null;
    _filterDateTo = null;
  });

  List<ExpenseModel> _applyFiltersAndSort(List<ExpenseModel> expenses) {
    var filtered = expenses.where((e) {
      if (_filterUser != null && e.paidBy != _filterUser) return false;
      if (_filterCategory != null && e.category != _filterCategory)
        return false;
      if (_filterDateFrom != null && e.date.isBefore(_filterDateFrom!))
        return false;
      if (_filterDateTo != null &&
          e.date.isAfter(_filterDateTo!.add(const Duration(days: 1))))
        return false;
      return true;
    }).toList();

    switch (_sortOption) {
      case _SortOption.timeDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
      case _SortOption.timeAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
      case _SortOption.amountDesc:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
      case _SortOption.amountAsc:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return filtered;
  }

  void _showFilterSheet(Map<String, String> nameMap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterBottomSheet(
        nameMap: nameMap,
        month: widget.month,
        filterUser: _filterUser,
        filterCategory: _filterCategory,
        filterDateFrom: _filterDateFrom,
        filterDateTo: _filterDateTo,
        sortOption: _sortOption,
        onApply: (user, category, from, to, sort) {
          setState(() {
            _filterUser = user;
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

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(
      monthExpensesProvider(
        MonthRoomKey(roomId: widget.roomId, month: widget.month),
      ),
    );
    final userId = ref.read(currentUserIdProvider);
    final room = ref.watch(roomStreamProvider(widget.roomId)).valueOrNull;
    final isAdmin =
        (room?.isAdmin(userId) ?? false) && (room?.canWrite(userId) ?? false);
    final members = ref.watch(
      monthParticipantIdsProvider(
        MonthBalanceKey(roomId: widget.roomId, month: widget.month),
      ),
    );
    final membersAsync = ref.watch(userProfilesByIdsProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }

    return Column(
      children: [
        // Always-visible chip bar: sort chips + filter icon
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).cardTheme.color ??
                  Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sortChip('Newest', _SortOption.timeDesc),
                        const SizedBox(width: 6),
                        _sortChip('Oldest', _SortOption.timeAsc),
                        const SizedBox(width: 6),
                        _sortChip('Amount \u2191', _SortOption.amountAsc),
                        const SizedBox(width: 6),
                        _sortChip('Amount \u2193', _SortOption.amountDesc),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _clearFilters,
                            child: Chip(
                              label: const Text(
                                'Clear',
                                style: TextStyle(fontSize: 11),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: _clearFilters,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter icon
                GestureDetector(
                  onTap: () => _showFilterSheet(nameMap),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 20,
                      color: _hasActiveFilters
                          ? Colors.white
                          : Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expense list
        Expanded(
          child: expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (expenses) {
              final filtered = _applyFiltersAndSort(expenses);
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _hasActiveFilters
                        ? 'No expenses match filters'
                        : 'No expenses this month',
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: filtered
                    .map(
                      (e) => _ExpenseTile(
                        expense: e,
                        isAdmin: isAdmin,
                        userId: userId,
                        roomId: widget.roomId,
                        nameMap: nameMap,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sortChip(String label, _SortOption option) {
    final selected = _sortOption == option;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _sortOption = option),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ========== FILTER BOTTOM SHEET ==========
class _FilterBottomSheet extends StatefulWidget {
  final Map<String, String> nameMap;
  final String month;
  final String? filterUser;
  final String? filterCategory;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final _SortOption sortOption;
  final void Function(String?, String?, DateTime?, DateTime?, _SortOption)
  onApply;
  final VoidCallback onClear;

  const _FilterBottomSheet({
    required this.nameMap,
    required this.month,
    required this.filterUser,
    required this.filterCategory,
    required this.filterDateFrom,
    required this.filterDateTo,
    required this.sortOption,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _user;
  late String? _category;
  late DateTime? _from;
  late DateTime? _to;
  late _SortOption _sort;

  @override
  void initState() {
    super.initState();
    _user = widget.filterUser;
    _category = widget.filterCategory;
    _from = widget.filterDateFrom;
    _to = widget.filterDateTo;
    _sort = widget.sortOption;
  }

  Future<void> _pickDate(bool isFrom) async {
    final parts = widget.month.split('-');
    final year = int.parse(parts[0]);
    final mon = int.parse(parts[1]);
    final firstDay = DateTime(year, mon, 1);
    final lastDay = DateTime(year, mon + 1, 0);
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? firstDay,
      firstDate: firstDay,
      lastDate: lastDay,
    );
    if (picked != null) {
      setState(() {
        if (isFrom)
          _from = picked;
        else
          _to = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
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

          Text('Paid by', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _user == null,
                onSelected: (_) => setState(() => _user = null),
              ),
              ...widget.nameMap.entries.map(
                (e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _user == e.key,
                  onSelected: (_) => setState(() => _user = e.key),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text('Category', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              ...RoomConstants.expenseCategories.map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text('Date range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(
                    _from != null
                        ? DateFormat('dd MMM').format(_from!)
                        : 'From',
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('\u2014'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(
                    _to != null ? DateFormat('dd MMM').format(_to!) : 'To',
                  ),
                ),
              ),
              if (_from != null || _to != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),

          Text('Sort by', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Newest'),
                selected: _sort == _SortOption.timeDesc,
                onSelected: (_) => setState(() => _sort = _SortOption.timeDesc),
              ),
              ChoiceChip(
                label: const Text('Oldest'),
                selected: _sort == _SortOption.timeAsc,
                onSelected: (_) => setState(() => _sort = _SortOption.timeAsc),
              ),
              ChoiceChip(
                label: const Text('Amount \u2191'),
                selected: _sort == _SortOption.amountAsc,
                onSelected: (_) =>
                    setState(() => _sort = _SortOption.amountAsc),
              ),
              ChoiceChip(
                label: const Text('Amount \u2193'),
                selected: _sort == _SortOption.amountDesc,
                onSelected: (_) =>
                    setState(() => _sort = _SortOption.amountDesc),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  widget.onApply(_user, _category, _from, _to, _sort),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  final ExpenseModel expense;
  final bool isAdmin;
  final String userId;
  final String roomId;
  final Map<String, String> nameMap;

  const _ExpenseTile({
    required this.expense,
    required this.isAdmin,
    required this.userId,
    required this.roomId,
    required this.nameMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomStreamProvider(roomId)).valueOrNull;
    final canDelete =
        (room?.canWrite(userId) ?? false) &&
        (expense.createdBy == userId || isAdmin);
    final icon =
        RoomConstants.categoryIcons[expense.category] ?? Icons.receipt_long;
    final paidByName = expense.paidBy == userId
        ? 'You'
        : (nameMap[expense.paidBy] ?? expense.paidBy);
    final hasReceipt =
        expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: appCardDecoration(context, accentColor: cs.primary),
      child: ListTile(
        tileColor: Colors.transparent,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(icon, size: 20, color: cs.primary)),
        ),
        title: Text(expense.title),
        subtitle: Text(
          '${expense.category} • ${DateFormat('dd MMM').format(expense.date)} • $paidByName',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasReceipt)
              IconButton(
                icon: Icon(
                  Icons.visibility,
                  size: 20,
                  color: const Color(0xFF10B981),
                ),
                tooltip: 'View Receipt',
                onPressed: () => _showReceipt(context, expense.receiptUrl!),
              ),
            Text(
              '₹${expense.amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
            ),
          ],
        ),
        onTap: () =>
            showViewExpenseSheet(context, roomId: roomId, expense: expense),
      ),
    );

    // Dismissible wrapper unchanged (only passes the tile)
    if (!canDelete) return tile;
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text('Delete "${expense.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await ref.read(deleteRoomExpenseProvider)(roomId, expense, userId);
          } catch (e) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to delete expense: $e')),
              );
          }
        }
        return false;
      },
      child: tile,
    );
  }

  void _showReceipt(BuildContext context, String url) {
    final isLocal = !url.startsWith('http');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: isLocal
                  ? Image.file(
                      File(url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Failed to load image'),
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Failed to load image'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== BILLS TAB ==========
class _BillsTab extends ConsumerWidget {
  final String roomId;
  final String month;
  const _BillsTab({required this.roomId, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(
      billsStreamProvider(MonthBillKey(roomId: roomId, month: month)),
    );
    final members = ref.watch(
      monthParticipantIdsProvider(
        MonthBalanceKey(roomId: roomId, month: month),
      ),
    );
    final membersAsync = ref.watch(userProfilesByIdsProvider(members));
    final userId = ref.read(currentUserIdProvider);
    final room = ref.watch(roomStreamProvider(roomId)).valueOrNull;
    final isAdmin =
        (room?.isAdmin(userId) ?? false) && (room?.canWrite(userId) ?? false);
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }

    return billsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bills) {
        if (bills.isEmpty)
          return const Center(child: Text('No bills this month'));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: bills.map((bill) {
            final paidBy = nameMap[bill.paidBy] ?? bill.paidBy;
            final icon = switch (bill.type) {
              BillType.rent => Icons.home,
              BillType.electricity => Icons.bolt,
              BillType.water => Icons.water_drop,
            };
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final billColor = switch (bill.type) {
              BillType.rent => const Color(0xFF6366F1),
              BillType.electricity => const Color(0xFFF59E0B),
              BillType.water => const Color(0xFF3B82F6),
            };
            final card = Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: appCardDecoration(context, accentColor: billColor),
              child: ListTile(
                tileColor: Colors.transparent,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: billColor.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(icon, size: 20, color: billColor)),
                ),
                title: Text(bill.typeName),
                subtitle: Text(
                  'Paid by $paidBy • ${DateFormat('dd MMM').format(bill.date)}',
                ),
                trailing: Text(
                  '₹${bill.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: billColor,
                  ),
                ),
                onTap: () =>
                    showViewBillSheet(context, roomId: roomId, bill: bill),
              ),
            );

            if (!(room?.canWrite(userId) ?? false) ||
                !(isAdmin || bill.paidBy == userId))
              return card;

            return Dismissible(
              key: Key(bill.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Bill'),
                    content: Text('Delete "${bill.typeName}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref.read(deleteRoomBillProvider)(
                      roomId,
                      bill,
                      userId,
                    );
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to delete bill: $e')),
                      );
                  }
                }
                return false;
              },
              child: card,
            );
          }).toList(),
        );
      },
    );
  }
}

// ========== SETTLEMENTS TAB ==========
// class _SettlementsTab extends ConsumerWidget {
//   final String roomId;
//   final String month;
//   const _SettlementsTab({required this.roomId, required this.month});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final userId = ref.watch(currentUserIdProvider);
//     final balanceKey = MonthBalanceKey(roomId: roomId, month: month);
//     final detailedMap = ref.watch(detailedDebtsMapProvider(balanceKey));
//     final members = ref.watch(currentRoomProvider)?.memberIds ?? [];
//     final membersAsync = ref.watch(userProfilesByIdsProvider(members));
//     final nameMap = <String, String>{};
//     if (membersAsync.hasValue) {
//       for (final m in membersAsync.value!) {
//         nameMap[m.uid] = m.name;
//       }
//     }
//     nameMap.putIfAbsent(userId, () => 'You');

//     // Generate all unordered pairs
//     final pairs = <(String, String)>[];
//     for (int i = 0; i < members.length; i++) {
//       for (int j = i + 1; j < members.length; j++) {
//         pairs.add((members[i], members[j]));
//       }
//     }

//     if (pairs.isEmpty) {
//       return const Center(child: Text('No members in this room'));
//     }

//     return ListView(
//       padding: const EdgeInsets.symmetric(vertical: 12),
//       children: pairs.map((pair) {
//         return PairSettlementCard(
//           memberA: pair.$1,
//           memberB: pair.$2,
//           detailedMap: detailedMap,
//           nameMap: nameMap,
//           userId: userId,
//           roomId: roomId,
//         );
//       }).toList(),
//     );
//   }
// }

class _SettlementsTab extends ConsumerWidget {
  final String roomId;
  final String month;
  const _SettlementsTab({required this.roomId, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final balanceKey = MonthBalanceKey(roomId: roomId, month: month);
    final detailedMap = ref.watch(detailedDebtsMapProvider(balanceKey));
    final expenseState = ref.watch(
      monthExpensesProvider(MonthRoomKey(roomId: roomId, month: month)),
    );
    final billState = ref.watch(
      billsStreamProvider(MonthBillKey(roomId: roomId, month: month)),
    );
    final paymentState = ref.watch(settlementsStreamProvider(roomId));
    if (expenseState.hasError || billState.hasError || paymentState.hasError) {
      return const Center(
        child: Text('Unable to load balances. Please try again.'),
      );
    }
    if (expenseState.isLoading ||
        billState.isLoading ||
        paymentState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final members = ref.watch(monthParticipantIdsProvider(balanceKey));
    final room = ref.watch(roomStreamProvider(roomId)).valueOrNull;
    final payments = paymentState.valueOrNull ?? [];
    final membersAsync = ref.watch(userProfilesByIdsProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }
    nameMap.putIfAbsent(userId, () => 'You');

    final pairs = <(String, String)>[];
    for (int i = 0; i < members.length; i++) {
      for (int j = i + 1; j < members.length; j++) {
        pairs.add((members[i], members[j]));
      }
    }

    if (pairs.isEmpty) {
      return const Center(child: Text('No expenses or payments this month'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: pairs.map((pair) {
        return PairSettlementTimeline(
          memberA: pair.$1,
          memberB: pair.$2,
          detailedMap: detailedMap,
          nameMap: nameMap,
          userId: userId,
          roomId: roomId,
          month: month,
          canSettle: room != null && !room.isArchived && !room.isLocked,
          settlements: payments
              .where((s) => s.effectiveMonth == month)
              .toList(),
        );
      }).toList(),
    );
  }
}
