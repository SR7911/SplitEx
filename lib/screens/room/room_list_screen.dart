import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(userRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rooms'),
        actions: [
          _NotificationBell(),
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Join Room',
            onPressed: () => context.push('/join-room'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(currentRoomProvider);
            },
          ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No rooms yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create a room or join one with an invite code'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final userId = ref.read(currentUserIdProvider);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(room.name[0].toUpperCase()),
                  ),
                  title: Text(room.name),
                  subtitle: Text(
                    '${room.memberIds.length} members • Code: ${room.inviteCode}',
                  ),
                  trailing: room.isAdmin(userId)
                      ? const Chip(label: Text('Admin'))
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(currentRoomProvider.notifier).state = room;
                    context.push('/room/${room.id}');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-room'),
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
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
        child: const Icon(Icons.notifications),
      ),
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
    );
  }
}
