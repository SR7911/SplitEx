import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class RoomSettingsScreen extends ConsumerWidget {
  final String roomId;
  const RoomSettingsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final userId = ref.read(currentUserIdProvider);

    return Scaffold(
      appBar: const AppHeader(showBack: true, title: 'Room Settings', showNotification: false),
      body: GradientBody(child: roomAsync.when(
        data: (room) {
          if (room == null) {
            return const Center(child: Text('Room not found'));
          }

          final isAdmin = room.isAdmin(userId);
          final membersAsync = ref.watch(roomMembersProvider(room.memberIds));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite Code', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 1,
                      )),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            room.inviteCode,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: room.inviteCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppSectionHeader(title: 'Members (${room.memberIds.length})'),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) => Column(
                  children: members.map((member) {
                    final memberIsAdmin = room.isAdmin(member.uid);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(member.name),
                      subtitle: Text(member.email),
                      trailing: memberIsAdmin
                          ? Chip(
                              label: const Text('Admin'),
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 12),
                              padding: EdgeInsets.zero,
                            )
                          : isAdmin
                              ? IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                                  onPressed: () => _confirmRemove(context, ref, roomId, member.uid, member.name),
                                )
                              : null,
                    );
                  }).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              if (!isAdmin)
                OutlinedButton.icon(
                  onPressed: () => _confirmLeave(context, ref, roomId, userId),
                  icon: Icon(Icons.exit_to_app, color: Theme.of(context).colorScheme.error),
                  label: Text('Leave Room', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      )),
    );
  }

  void _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String roomId,
    String memberId,
    String memberName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $memberName from this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(roomServiceProvider).removeMember(roomId, memberId);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String roomId,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Room'),
        content: const Text('Are you sure you want to leave this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(roomServiceProvider).leaveRoom(roomId, userId);
              Navigator.pop(ctx);
              context.go('/');
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
