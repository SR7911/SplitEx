import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/group_model.dart';
import 'package:split_ex/providers/group_provider.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      floatingActionButton: Column(
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
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (groups) {
          if (groups.isEmpty) return const _EmptyGroupsState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: groups.length + 1,
            separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 16) : const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == 0) return _GroupsSummaryHeader(groups: groups);
              return _GroupCard(group: groups[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupModel group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final isArchived = group.isArchived;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isArchived ? null : () => context.push('/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isArchived
                      ? Colors.grey.withOpacity(0.1)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: isArchived ? Colors.grey : Theme.of(context).colorScheme.primary,
                ),
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
                              fontSize: 15,
                              color: isArchived ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (isArchived)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Archived', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.memberIds.length} members • ${DateFormat('dd MMM yyyy').format(group.startDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isArchived) const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsSummaryHeader extends ConsumerWidget {
  final List<GroupModel> groups;
  const _GroupsSummaryHeader({required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGroups = groups.where((g) => !g.isArchived).toList();
    final totalMembers = activeGroups.fold<int>(0, (s, g) => s + g.memberIds.length);
    // Sum net balance across all active groups
    double netBalance = 0;
    for (final g in activeGroups) {
      netBalance += ref.watch(groupUserBalanceProvider(g.id));
    }
    final isOwed = netBalance > 0.01;
    final owes = netBalance < -0.01;
    final balanceColor = isOwed ? Colors.green : owes ? Colors.red : Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SummaryPill(
                icon: Icons.groups_rounded,
                label: 'Groups',
                value: '${activeGroups.length}',
                color: Theme.of(context).colorScheme.primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryPill(
                icon: Icons.person_rounded,
                label: 'Members',
                value: '$totalMembers',
                color: Colors.teal,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryPill(
                icon: isOwed ? Icons.arrow_downward_rounded : owes ? Icons.arrow_upward_rounded : Icons.check_circle_rounded,
                label: isOwed ? 'You are owed' : owes ? 'You owe' : 'Settled',
                value: netBalance.abs() < 0.01 ? '—' : '₹${netBalance.abs().toStringAsFixed(0)}',
                color: balanceColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Your Groups', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _SummaryPill({required this.icon, required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No groups yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Create a group for trips, events, or outings',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/groups/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/groups/join'),
              icon: const Icon(Icons.link),
              label: const Text('Join with Code'),
            ),
          ],
        ),
      ),
    );
  }
}
