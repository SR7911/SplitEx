import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';

class RoomSettingsScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomSettingsScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends ConsumerState<RoomSettingsScreen> {
  bool _busy = false;

  Future<void> _confirm(
    String title,
    String message,
    String label,
    Future<void> Function() action, {
    bool leave = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (leave) {
        ref.invalidate(currentRoomProvider);
        context.go('/');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title completed')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final service = ref.read(roomServiceProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AppHeader(
        showBack: true,
        title: 'Room Settings',
        showNotification: false,
      ),
      body: GradientBody(
        child: roomAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load room: $e')),
          data: (room) {
            if (room == null || !room.canRead(userId))
              return const Center(child: Text('Room unavailable'));
            final admin = room.isAdmin(userId);
            final active = room.isMember(userId);
            final profiles = ref.watch(
              userProfilesByIdsProvider(room.historicalMemberIds),
            );
            final names = {
              for (final member in profiles.valueOrNull ?? [])
                member.uid: member.name,
            };
            final formerIds = room.historicalMemberIds
                .where((id) => !room.isMember(id))
                .toList();
            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (room.isArchived || !active)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      margin: const EdgeInsets.only(bottom: AppSpacing.base),
                      decoration: appCardDecoration(context),
                      child: Text(
                        room.isArchived
                            ? 'Archived room. Expenses, bills, balances and payment history are preserved. Restore the room to make changes or settle balances.'
                            : 'You have left this room. Your history and outstanding balances are preserved. You can still settle previous expenses.',
                      ),
                    ),
                  if (active && !room.isArchived && !room.isLocked)
                    Container(
                      decoration: appCardDecoration(context),
                      child: ListTile(
                        leading: Icon(
                          Icons.vpn_key_outlined,
                          color: cs.primary,
                        ),
                        title: const Text('Invite Code'),
                        subtitle: Text(
                          room.inviteCode,
                          style: const TextStyle(
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Copy invite code',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: room.inviteCode),
                            );
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')),
                              );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.base),
                  AppSectionHeader(
                    title: 'Active members (${room.memberIds.length})',
                  ),
                  if (profiles.isLoading) const LinearProgressIndicator(),
                  if (profiles.hasError)
                    const Text(
                      'Names could not be loaded. Member IDs are shown below.',
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  ...room.memberIds.map((id) {
                    final name = names[id] ?? id;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                      ),
                      title: Text(name),
                      subtitle: room.isAdmin(id) ? const Text('Admin') : null,
                      trailing:
                          admin && active && id != userId && !room.isArchived
                          ? PopupMenuButton<String>(
                              tooltip: 'Manage member',
                              onSelected: (value) {
                                if (value == 'transfer') {
                                  _confirm(
                                    'Transfer admin',
                                    'Make $name the room admin? You will remain a member and can then leave without losing the room history.',
                                    'Transfer',
                                    () => service.transferAdmin(
                                      widget.roomId,
                                      userId,
                                      id,
                                    ),
                                  );
                                } else {
                                  _confirm(
                                    'Remove member',
                                    'Remove $name from active membership? Their expenses, payments and outstanding balances will remain in the room history.',
                                    'Remove',
                                    () => service.removeMember(
                                      widget.roomId,
                                      id,
                                      performedBy: userId,
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Text('Make admin'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove member'),
                                ),
                              ],
                            )
                          : null,
                    );
                  }),
                  if (formerIds.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.base),
                    AppSectionHeader(
                      title: 'Former members (${formerIds.length})',
                    ),
                    ...formerIds.map(
                      (id) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(names[id] ?? id),
                        subtitle: const Text('History retained'),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (admin && active)
                    TextButton.icon(
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Recover former members'),
                      onPressed: () => _confirm(
                        'Recover former members',
                        'Restore historical access for people recorded in older room expenses and payments? Active membership and expense amounts stay the same.',
                        'Recover',
                        () => service.restoreHistoricalParticipants(
                          widget.roomId,
                          userId,
                        ),
                      ),
                    ),
                  if (admin)
                    OutlinedButton.icon(
                      icon: Icon(
                        room.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      label: Text(
                        room.isArchived ? 'Restore Room' : 'Archive Room',
                      ),
                      onPressed: () => _confirm(
                        room.isArchived ? 'Restore room' : 'Archive room',
                        room.isArchived
                            ? 'Reopen this room for expenses and settlements? If everyone has left, you will rejoin as admin.'
                            : 'Preserve this room as read-only history? Outstanding balances remain recorded. You can restore it later to settle them.',
                        room.isArchived ? 'Restore' : 'Archive',
                        () => service.setArchived(
                          widget.roomId,
                          userId,
                          !room.isArchived,
                        ),
                      ),
                    ),
                  if (active) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      icon: Icon(Icons.exit_to_app, color: cs.error),
                      label: Text(
                        'Leave Room',
                        style: TextStyle(color: cs.error),
                      ),
                      onPressed: () => _confirm(
                        'Leave room',
                        admin && room.memberIds.length > 1
                            ? 'Transfer admin responsibility to another active member before leaving.'
                            : room.memberIds.length == 1
                            ? 'You are the last member. Leaving will archive the room and preserve all records and outstanding balances.'
                            : 'Leave active membership? Your previous expenses and balances remain accessible. Future expenses will not include you.',
                        'Leave',
                        () => service.leaveRoom(widget.roomId, userId),
                        leave: true,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
