import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/group_model.dart';
import 'package:split_ex/providers/group_provider.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kBlue   = Color(0xFF3B82F6);
const _kIndigo = Color(0xFF6366F1);
const _kTeal   = Color(0xFF14B8A6);

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Stack(
      children: [
        groupsAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: 5,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: i == 0
                  ? AppLoadingShimmer.block(height: 200)
                  : AppLoadingShimmer.block(height: 72),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (groups) {
            if (groups.isEmpty) return const _EmptyGroupsState();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _GroupsHeader(),
                const SizedBox(height: 20),
                _GroupsHeroCard(groups: groups),
                const SizedBox(height: 16),
                _GroupsMiniStatRow(groups: groups),
                const SizedBox(height: 20),
                _GroupsQuickActions(),
                const SizedBox(height: 20),
                const AppSectionHeader(title: 'Your Groups', actionLabel: null, onAction: null),
                const SizedBox(height: 14),
                ...groups.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key == groups.length - 1 ? 0 : 10),
                  child: _GroupCard(group: e.value),
                )),
              ],
            );
          },
        ),
        Positioned(
          right: 16, bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: () => context.push('/groups/join'),
                heroTag: 'join-group',
                child: const Icon(Icons.group_add_outlined),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                onPressed: () => context.push('/groups/create'),
                heroTag: 'create-group',
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -- _GroupsHeader ---------------------------------------------------------

class _GroupsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Groups',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Split expenses with friends & groups',
          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

// -- _GroupsHeroCard -------------------------------------------------------

class _GroupsHeroCard extends ConsumerWidget {
  final List<GroupModel> groups;
  const _GroupsHeroCard({required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final activeGroups = groups.where((g) => !g.isArchived).toList();
    double netBalance  = 0;
    for (final g in activeGroups) {
      netBalance += ref.watch(groupUserBalanceProvider(g.id));
    }
    final isOwed     = netBalance > 0.01;
    final owes       = netBalance < -0.01;
    final isSettled  = !isOwed && !owes;
    final gradientColors = isOwed
        ? (isDark ? [const Color(0xFF064E3B), const Color(0xFF065F46)] : [const Color(0xFF059669), const Color(0xFF0D9488)])
        : owes
            ? (isDark ? [const Color(0xFF7F1D1D), const Color(0xFF831843)] : [const Color(0xFFDC2626), const Color(0xFFDB2777)])
            : (isDark ? [const Color(0xFF064E3B), const Color(0xFF065F46)] : [const Color(0xFF059669), const Color(0xFF0D9488)]);

    final onCard      = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.85);
    double totalGroupSpent = 0;
    for (final g in activeGroups) {
      totalGroupSpent += ref.watch(groupTotalExpenseProvider(g.id));
    }

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
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.groups_rounded, size: 12, color: onCard),
                          const SizedBox(width: 5),
                          Text('Group Expenses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onCard)),
                        ]),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
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
                  Text(
                    isSettled ? '₹0' : '₹${netBalance.abs().toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1.5, height: 1.1),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AppHeroChip(icon: Icons.groups_rounded,       label: 'Groups', value: '${activeGroups.length}',                onCard: onCard, onCardMuted: onCardMuted),
                      const SizedBox(width: 10),
                      AppHeroChip(icon: Icons.receipt_long_rounded,  label: 'Spent',  value: '₹${totalGroupSpent.toStringAsFixed(0)}', onCard: onCard, onCardMuted: onCardMuted),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            isSettled ? Icons.check_circle_rounded : isOwed ? Icons.south_rounded : Icons.north_rounded,
                            size: 16, color: onCard,
                          ),
                          const SizedBox(height: 2),
                          Text(isSettled ? '✓' : isOwed ? '+' : '-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard)),
                          Text('net', style: TextStyle(fontSize: 9, color: onCardMuted)),
                        ]),
                      ),
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

// _HeroChip replaced by AppHeroChip from design_system

// -- _GroupsMiniStatRow ----------------------------------------------------

class _GroupsMiniStatRow extends ConsumerWidget {
  final List<GroupModel> groups;
  const _GroupsMiniStatRow({required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGroups = groups.where((g) => !g.isArchived).toList();
    final totalMembers = activeGroups.fold<int>(0, (s, g) => s + g.memberIds.length);
    double netBalance  = 0;
    for (final g in activeGroups) {
      netBalance += ref.watch(groupUserBalanceProvider(g.id));
    }
    final isOwed = netBalance > 0.01;
    final balColor = isOwed ? _kGreen : netBalance < -0.01 ? _kRed : _kIndigo;

    return Row(
      children: [
        Expanded(child: AppMiniStatCard(label: 'Groups',  value: '${activeGroups.length}',                    icon: Icons.groups_rounded,  color: _kBlue)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Members', value: '$totalMembers',                              icon: Icons.people_rounded,  color: _kTeal)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: isOwed ? 'Owed' : 'You Owe', value: '₹${netBalance.abs().toStringAsFixed(0)}', icon: isOwed ? Icons.south_rounded : Icons.north_rounded, color: balColor)),
      ],
    );
  }
}

// -- _GroupsQuickActions ---------------------------------------------------

class _GroupsQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WideQuickAction(
            icon: Icons.add_rounded,
            label: 'Create Group',
            color: _kGreen,
            onTap: () => context.push('/groups/create'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _WideQuickAction(
            icon: Icons.group_add_outlined,
            label: 'Join Group',
            color: _kBlue,
            onTap: () => context.push('/groups/join'),
          ),
        ),
      ],
    );
  }
}

// _QuickAction replaced by AppQuickActionTile from design_system

class _WideQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _WideQuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupModel group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final isArchived = group.isArchived;
    final accentColor = isArchived ? cs.onSurface.withValues(alpha: 0.3) : cs.primary;

    return GestureDetector(
      onTap: isArchived ? null : () => context.push('/groups/${group.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: appCardDecoration(context, accentColor: isArchived ? null : accentColor),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
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
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.groups_rounded, size: 22, color: accentColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isArchived ? cs.onSurface.withValues(alpha: 0.4) : cs.onSurface,
                                ),
                              ),
                            ),
                            if (isArchived)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Archived', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people_outline_rounded, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              '${group.memberIds.length} members',
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 3, height: 3,
                              decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.25), shape: BoxShape.circle),
                            ),
                            Icon(Icons.calendar_today_rounded, size: 11, color: cs.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(group.startDate),
                              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isArchived)
                    Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.groups_outlined,
      title: 'No groups yet',
      subtitle: 'Create a group for trips, events, or outings',
      actionLabel: 'Create Group',
      onAction: () => context.push('/groups/create'),
    );
  }
}
