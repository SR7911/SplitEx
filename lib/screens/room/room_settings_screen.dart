import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/room_provider.dart';

class RoomSettingsScreen extends ConsumerWidget {
  final String roomId;
  const RoomSettingsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final userId = ref.read(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Room Settings')),
      body: roomAsync.when(
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
                      Text(
                        'Invite Code',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            room.inviteCode,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: room.inviteCode),
                              );
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
              Text(
                'Members (${room.memberIds.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) => Column(
                  children: members.map((member) {
                    final memberIsAdmin = room.isAdmin(member.uid);
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(member.name),
                      subtitle: Text(member.email),
                      trailing: memberIsAdmin
                          ? const Chip(label: Text('Admin'))
                          : isAdmin
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmRemove(
                                    context,
                                    ref,
                                    roomId,
                                    member.uid,
                                    member.name,
                                  ),
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
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text(
                    'Leave Room',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
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
