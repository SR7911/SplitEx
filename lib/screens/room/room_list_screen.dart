import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/models/room_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/dashboard_provider.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/providers/settlement_provider.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kBlue   = Color(0xFF3B82F6);
const _kAmber  = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);

const _kPalette = [_kBlue, _kGreen, _kAmber, _kIndigo, _kTeal, _kPurple, _kRed];

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(userRoomsProvider);
    final profile   = ref.watch(userProfileProvider).valueOrNull;
    final userName  = profile?.name ?? 'User';

    return Stack(
      children: [
        roomsAsync.when(
          loading: () => _buildLoading(),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rooms) {
            if (rooms.isEmpty) {
              return AppEmptyState(
                icon: Icons.home_outlined,
                title: 'No rooms yet',
                subtitle: 'Create a room or join one with an invite code',
                actionLabel: 'Create Room',
                onAction: () => context.push('/create-room'),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _GreetingHeader(userName: userName),
                const SizedBox(height: 20),
                _RoomHeroCard(rooms: rooms),
                const SizedBox(height: 16),
                _RoomMiniStatRow(rooms: rooms),
                const SizedBox(height: 16),
                _RoomSummaryCard(rooms: rooms),
                const SizedBox(height: 20),
                _RoomQuickActions(),
                const SizedBox(height: 20),
                AppSectionHeader(title: 'Your Rooms', actionLabel: null, onAction: null),
                const SizedBox(height: 14),
                ...rooms.asMap().entries.map((entry) => Padding(
                  padding: EdgeInsets.only(bottom: entry.key == rooms.length - 1 ? 0 : 10),
                  child: _RoomCard(room: entry.value, index: entry.key),
                )),
                const SizedBox(height: 20),
                _RecentRoomActivities(),
              ],
            );
          },
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            onPressed: () => context.push('/create-room'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
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

// -- _GreetingHeader -------------------------------------------------------

class _GreetingHeader extends ConsumerWidget {
  final String userName;
  const _GreetingHeader({required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs    = Theme.of(context).colorScheme;
    final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Rooms',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage shared living expenses',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => GoRouter.of(context).push('/notifications'),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count', style: const TextStyle(fontSize: 10)),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          onPressed: () => GoRouter.of(context).push('/join-room'),
          icon: const Icon(Icons.login_rounded),
          tooltip: 'Join Room',
        ),
      ],
    );
  }
}

// -- _RoomHeroCard ---------------------------------------------------------

class _RoomHeroCard extends ConsumerWidget {
  final List<RoomModel> rooms;
  const _RoomHeroCard({required this.rooms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final month       = DateFormat('yyyy-MM').format(DateTime.now());
    final netBalance  = ref.watch(monthOverallBalanceProvider(month));
    final isOwed      = netBalance > 0.01;
    final owes        = netBalance < -0.01;
    final isSettled   = !isOwed && !owes;
    final activeRooms = rooms.where((r) => !r.isLocked).length;
    final totalMembers = rooms.fold<int>(0, (s, r) => s + r.memberIds.length);

    final gradientColors = isOwed
        ? (isDark
            ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
            : [const Color(0xFF059669), const Color(0xFF0D9488)])
        : owes
            ? (isDark
                ? [const Color(0xFF7F1D1D), const Color(0xFF831843)]
                : [const Color(0xFFDC2626), const Color(0xFFDB2777)])
            : (isDark
                ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                : [const Color(0xFF059669), const Color(0xFF0D9488)]);

    final onCard      = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.85);

    // Total spent this month across all rooms for progress bar
    double totalSpent = 0;
    for (final room in rooms) {
      final expenses = ref.watch(expensesStreamProvider(room.id)).valueOrNull ?? [];
      totalSpent += expenses.fold<double>(0, (s, e) => s + e.amount);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -40, right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30, left: -30,
              child: IgnorePointer(
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home_rounded, size: 12, color: onCard),
                            const SizedBox(width: 5),
                            Text('Room Expenses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onCard)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSettled ? 'All Settled' : isOwed ? 'You\'re Owed' : 'You Owe',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: onCard),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isSettled ? 'Net Balance' : isOwed ? 'You\'re Owed' : 'You Owe',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onCardMuted, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: netBalance.abs()),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      isSettled ? '₹0' : '₹${value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 42, fontWeight: FontWeight.w800,
                        color: onCard, letterSpacing: -1.5, height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AppHeroChip(icon: Icons.home_rounded,         label: 'Rooms',   value: '${rooms.length}',                        onCard: onCard, onCardMuted: onCardMuted),
                      const SizedBox(width: 10),
                      AppHeroChip(icon: Icons.receipt_long_rounded,  label: 'Spent',   value: '₹${totalSpent.toStringAsFixed(0)}',      onCard: onCard, onCardMuted: onCardMuted),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSettled ? Icons.check_circle_rounded : isOwed ? Icons.south_rounded : Icons.north_rounded,
                              size: 16, color: onCard,
                            ),
                            const SizedBox(height: 2),
                            Text(isSettled ? '✓' : isOwed ? '+' : '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard)),
                            Text('net', style: TextStyle(fontSize: 9, color: onCardMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (totalSpent > 0) ...[
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('₹${totalSpent.toStringAsFixed(0)} spent this month', style: TextStyle(fontSize: 10, color: onCardMuted)),
                        Text('${rooms.length} room${rooms.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: onCard)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      // Use net balance magnitude as a proxy: >5000 = high, >2000 = mid
                      final absBalance = netBalance.abs();
                      final spendLevel = totalSpent > 10000
                          ? 1.0
                          : totalSpent > 3000
                              ? 0.65
                              : 0.35;
                      final barColor = owes
                          ? const Color(0xFFFCA5A5)   // red-tinted when you owe
                          : isOwed
                              ? const Color(0xFF86EFAC) // green-tinted when owed
                              : Colors.white.withValues(alpha: 0.9);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: spendLevel,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      );
                    }),
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

// -- _RoomMiniStatRow ------------------------------------------------------

class _RoomMiniStatRow extends ConsumerWidget {
  final List<RoomModel> rooms;
  const _RoomMiniStatRow({required this.rooms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalMembers = rooms.fold<int>(0, (s, r) => s + r.memberIds.length);
    final lockedCount  = rooms.where((r) => r.isLocked).length;

    return Row(
      children: [
        Expanded(child: AppMiniStatCard(label: 'Total Rooms',   value: '${rooms.length}', icon: Icons.home_rounded,    color: _kBlue)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Total Members', value: '$totalMembers',   icon: Icons.people_rounded,  color: _kTeal)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Locked',        value: '$lockedCount',    icon: Icons.lock_rounded,    color: _kAmber)),
      ],
    );
  }
}

// -- _RoomSummaryCard ------------------------------------------------------

class _RoomSummaryCard extends ConsumerWidget {
  final List<RoomModel> rooms;
  const _RoomSummaryCard({required this.rooms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final month  = DateFormat('yyyy-MM').format(DateTime.now());

    double totalSpent = 0;
    int pendingCount  = 0;

    for (final room in rooms) {
      final expenses = ref.watch(expensesStreamProvider(room.id)).valueOrNull ?? [];
      totalSpent += expenses.fold<double>(0, (s, e) => s + e.amount);
      final userId = ref.watch(currentUserIdProvider);
      final pending = ref.watch(pendingSettlementsProvider(room.id)).valueOrNull ?? [];
      pendingCount += pending.length;
    }

    final spentRatio = totalSpent > 0 ? (totalSpent / (totalSpent + 1)).clamp(0.0, 1.0) : 0.0;
    final statusColor = pendingCount == 0 ? _kGreen : pendingCount <= 2 ? _kAmber : _kRed;
    final statusLabel = pendingCount == 0 ? 'All Settled' : '$pendingCount Pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSectionHeader(title: 'This Month', actionLabel: null, onAction: null),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryStatTile(
                  label: 'Total Spent',
                  value: '₹${totalSpent.toStringAsFixed(0)}',
                  icon: Icons.receipt_long_rounded,
                  color: _kBlue,
                  isDark: isDark,
                  cs: cs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStatTile(
                  label: 'Settlements',
                  value: pendingCount == 0 ? 'Clear' : '$pendingCount due',
                  icon: Icons.handshake_outlined,
                  color: statusColor,
                  isDark: isDark,
                  cs: cs,
                ),
              ),
            ],
          ),
          if (totalSpent > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: spentRatio,
                minHeight: 7,
                backgroundColor: cs.outline.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_kBlue),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '₹${totalSpent.toStringAsFixed(0)} across ${rooms.length} room${rooms.length != 1 ? 's' : ''} in ${DateFormat('MMMM').format(DateTime.now())}',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  const _SummaryStatTile({
    required this.label, required this.value, required this.icon,
    required this.color, required this.isDark, required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- _RoomQuickActions -----------------------------------------------------

class _RoomQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      AppQuickActionTile(icon: Icons.add_rounded,              label: 'Create',   color: _kGreen,  onTap: () => context.push('/create-room')),
      AppQuickActionTile(icon: Icons.login_rounded,            label: 'Join',     color: _kBlue,   onTap: () => context.push('/join-room')),
      AppQuickActionTile(icon: Icons.handshake_outlined,       label: 'Settle',   color: _kTeal,   onTap: () => context.push('/settlement')),
      AppQuickActionTile(icon: Icons.bar_chart_rounded,        label: 'Analytics',color: _kIndigo, onTap: () => context.push('/analytics')),
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

// -- _RoomCard -------------------------------------------------------------

class _RoomCard extends ConsumerWidget {
  final RoomModel room;
  final int index;
  const _RoomCard({required this.room, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final userId  = ref.read(currentUserIdProvider);
    final accent  = _kPalette[index % _kPalette.length];
    final isAdmin = room.isAdmin(userId);

    return InkWell(
      onTap: () {
        ref.read(currentRoomProvider.notifier).state = room;
        context.push('/room/${room.id}');
      },
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: appCardDecoration(context, accentColor: accent),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
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
                      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        room.name[0].toUpperCase(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.people_outline_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              '${room.memberIds.length} members',
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 3, height: 3,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Icon(Icons.vpn_key_outlined, size: 11, color: cs.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              room.inviteCode,
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (room.isLocked)
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
                        color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent)),
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

// -- _RecentRoomActivities -------------------------------------------------

class _RecentRoomActivities extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs         = Theme.of(context).colorScheme;
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final activities = ref.watch(recentActivitiesProvider);

    return Container(
      decoration: BoxDecoration(
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
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Recent Activity', actionLabel: null, onAction: null),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.history_rounded, size: 26, color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(height: 10),
                    Text('No recent activity', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...activities.asMap().entries.map((entry) {
              final activity = entry.value;
              final isLast   = entry.key == activities.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: _ActivityRow(activity: activity, isDark: isDark, cs: cs),
              );
            }),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityModel activity;
  final bool isDark;
  final ColorScheme cs;
  const _ActivityRow({required this.activity, required this.isDark, required this.cs});

  IconData get _icon => switch (activity.type) {
    ActivityType.expenseAdded       => Icons.add_circle_outline_rounded,
    ActivityType.expenseEdited      => Icons.edit_outlined,
    ActivityType.expenseDeleted     => Icons.delete_outline_rounded,
    ActivityType.billAdded          => Icons.receipt_outlined,
    ActivityType.billEdited         => Icons.edit_note_rounded,
    ActivityType.billDeleted        => Icons.delete_outline_rounded,
    ActivityType.settlementCreated  => Icons.handshake_outlined,
    ActivityType.settlementConfirmed => Icons.check_circle_outline_rounded,
    ActivityType.memberJoined       => Icons.person_add_outlined,
    ActivityType.memberLeft         => Icons.person_remove_outlined,
    ActivityType.roomCreated        => Icons.home_outlined,
    ActivityType.roomSettingsChanged => Icons.settings_outlined,
  };

  Color get _accent => switch (activity.type) {
    ActivityType.expenseAdded       => _kBlue,
    ActivityType.expenseEdited      => _kIndigo,
    ActivityType.expenseDeleted     => _kRed,
    ActivityType.billAdded          => _kTeal,
    ActivityType.billEdited         => _kTeal,
    ActivityType.billDeleted        => _kRed,
    ActivityType.settlementCreated  => _kAmber,
    ActivityType.settlementConfirmed => _kGreen,
    ActivityType.memberJoined       => _kGreen,
    ActivityType.memberLeft         => _kAmber,
    ActivityType.roomCreated        => _kBlue,
    ActivityType.roomSettingsChanged => _kPurple,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM • hh:mm a').format(activity.createdAt),
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
