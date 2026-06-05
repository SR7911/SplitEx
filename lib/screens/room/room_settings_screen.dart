import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/providers/theme_provider.dart';

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
              // Invite Code Card
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
                                  ClipboardData(text: room.inviteCode));
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
              // Members
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
                        child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(member.name),
                      subtitle: Text(member.email),
                      trailing: memberIsAdmin
                          ? const Chip(label: Text('Admin'))
                          : isAdmin
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  onPressed: () => _confirmRemove(
                                      context, ref, roomId, member.uid, member.name),
                                )
                              : null,
                    );
                  }).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              // Theme Settings
              Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _ThemeTile(ref: ref),
                    const Divider(height: 1),
                    _PaletteTile(ref: ref),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Leave Room
              if (!isAdmin)
                OutlinedButton.icon(
                  onPressed: () => _confirmLeave(context, ref, roomId, userId),
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text('Leave Room',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, String roomId,
      String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $memberName from this room?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
      BuildContext context, WidgetRef ref, String roomId, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Room'),
        content: const Text('Are you sure you want to leave this room?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

class _ThemeTile extends StatelessWidget {
  final WidgetRef ref;
  const _ThemeTile({required this.ref});

  @override
  Widget build(BuildContext context) {
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
      onTap: () => _showThemeDialog(context),
    );
  }

  void _showThemeDialog(BuildContext context) {
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
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).setMode(v!);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  final WidgetRef ref;
  const _PaletteTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentPalette = ref.watch(appPaletteProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette, size: 22),
              const SizedBox(width: 12),
              Text('Color — ${AppTheme.paletteName(currentPalette)}',
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppPalette.values.map((palette) {
              final isSelected = palette == currentPalette;
              return GestureDetector(
                onTap: () => ref.read(appPaletteProvider.notifier).setPalette(palette),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.paletteColor(palette),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppTheme.paletteColor(palette).withOpacity(0.4), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
