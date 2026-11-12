import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';

const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kIndigo = Color(0xFF6366F1);
const _kPurple = Color(0xFF8B5CF6);

// Member pill colors by index — cycles through palette for variety
const _kMemberColors = [_kBlue, _kTeal, _kGreen, _kPurple, _kAmber, _kIndigo];

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
    Color? actionColor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: actionColor != null
                ? FilledButton.styleFrom(backgroundColor: actionColor)
                : null,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title completed')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final service = ref.read(roomServiceProvider);

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
            if (!room.isAdmin(userId))
              return Center(
                child: AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Admin only',
                  subtitle: 'Only the room admin can access settings',
                ),
              );
            final admin = room.isAdmin(userId);
            final active = room.isMember(userId);
            final profiles = ref.watch(
              userProfilesByIdsProvider(room.historicalMemberIds),
            );
            final names = {
              for (final m in profiles.valueOrNull ?? []) m.uid: m.name,
            };
            final formerIds = room.historicalMemberIds
                .where((id) => !room.isMember(id))
                .toList();

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base, AppSpacing.sm,
                  AppSpacing.base, 40,
                ),
                children: [
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // ── Status banner (archived / former member) ──────────────
                  if (room.isArchived || !active)
                    _StatusBanner(
                      message: room.isArchived
                          ? 'Archived room. Expenses, bills, balances and payment history are preserved. Restore the room to make changes or settle balances.'
                          : 'You have left this room. Your history and outstanding balances are preserved. You can still settle previous expenses.',
                      color: room.isArchived ? _kAmber : _kBlue,
                    ),

                  // ── Invite code card ──────────────────────────────────────
                  if (active && !room.isArchived && !room.isLocked) ...[
                    _InviteCodeCard(inviteCode: room.inviteCode),
                    const SizedBox(height: AppSpacing.base),
                  ],

                  // ── Active members ────────────────────────────────────────
                  AppSectionHeader(
                    title: 'Active Members (${room.memberIds.length})',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (profiles.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: LinearProgressIndicator(),
                    ),
                  ...room.memberIds.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final id = entry.value;
                    final name = names[id] ?? id;
                    final isAdminMember = room.isAdmin(id);
                    final color = _kMemberColors[idx % _kMemberColors.length];
                    return _MemberTile(
                      name: name,
                      isAdmin: isAdminMember,
                      color: color,
                      trailing: admin && active && id != userId && !room.isArchived
                          ? PopupMenuButton<String>(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              tooltip: 'Manage member',
                              onSelected: (value) {
                                if (value == 'transfer') {
                                  _confirm(
                                    'Transfer Admin',
                                    'Make $name the room admin? You will remain a member.',
                                    'Transfer',
                                    () => service.transferAdmin(widget.roomId, userId, id),
                                    actionColor: _kIndigo,
                                  );
                                } else {
                                  _confirm(
                                    'Remove Member',
                                    'Remove $name from active membership? Their expenses and balances remain in history.',
                                    'Remove',
                                    () => service.removeMember(
                                      widget.roomId, id, performedBy: userId,
                                    ),
                                    actionColor: _kRed,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(children: [
                                    Icon(Icons.admin_panel_settings_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Make Admin'),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Row(children: [
                                    Icon(Icons.person_remove_rounded, size: 16, color: _kRed),
                                    SizedBox(width: 8),
                                    Text('Remove', style: TextStyle(color: _kRed)),
                                  ]),
                                ),
                              ],
                            )
                          : null,
                    );
                  }),

                  // ── Former members ────────────────────────────────────────
                  if (formerIds.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.base),
                    AppSectionHeader(
                      title: 'Former Members (${formerIds.length})',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...formerIds.asMap().entries.map((entry) {
                      final name = names[entry.value] ?? entry.value;
                      final color = _kMemberColors[entry.key % _kMemberColors.length];
                      return _MemberTile(
                        name: name,
                        isAdmin: false,
                        color: color,
                        dimmed: true,
                      );
                    }),
                  ],

                  // ── Admin actions ─────────────────────────────────────────
                  const SizedBox(height: AppSpacing.xl),
                  if (admin && active) ...[
                    AppSectionHeader(title: 'Admin Actions'),
                    const SizedBox(height: AppSpacing.sm),
                    _ActionCard(
                      icon: Icons.history_rounded,
                      label: 'Recover Former Members',
                      subtitle: 'Restore historical access for past participants',
                      color: _kTeal,
                      onTap: () => _confirm(
                        'Recover Former Members',
                        'Restore historical access for people recorded in older room expenses and payments?',
                        'Recover',
                        () => service.restoreHistoricalParticipants(widget.roomId, userId),
                        actionColor: _kTeal,
                      ),
                    ),
                    if (room.memberIds.length > 1 && !room.isArchived) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _ActionCard(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Transfer Ownership',
                        subtitle: 'Hand admin role to another member',
                        color: _kIndigo,
                        onTap: () async {
                          final otherMembers = room.memberIds
                              .where((id) => id != userId)
                              .toList();
                          final selected = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                              title: const Text('Transfer Ownership To'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: otherMembers.asMap().entries.map((e) {
                                  final name = names[e.value] ?? e.value;
                                  final color = _kMemberColors[e.key % _kMemberColors.length];
                                  return _MemberTile(
                                    name: name,
                                    isAdmin: false,
                                    color: color,
                                    onTap: () => Navigator.pop(ctx, e.value),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                          if (selected == null || !mounted) return;
                          final name = names[selected] ?? selected;
                          _confirm(
                            'Transfer Ownership',
                            'Make $name the room admin? You will remain a member.',
                            'Transfer',
                            () => service.transferAdmin(widget.roomId, userId, selected),
                            actionColor: _kIndigo,
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _ActionCard(
                      icon: room.isArchived
                          ? Icons.unarchive_rounded
                          : Icons.archive_rounded,
                      label: room.isArchived ? 'Restore Room' : 'Archive Room',
                      subtitle: room.isArchived
                          ? 'Reopen this room for expenses and settlements'
                          : 'Preserve as read-only history — can be restored later',
                      color: _kAmber,
                      onTap: () => _confirm(
                        room.isArchived ? 'Restore Room' : 'Archive Room',
                        room.isArchived
                            ? 'Reopen this room for expenses and settlements? If everyone has left, you will rejoin as admin.'
                            : 'Preserve this room as read-only history? Outstanding balances remain recorded.',
                        room.isArchived ? 'Restore' : 'Archive',
                        () => service.setArchived(widget.roomId, userId, !room.isArchived),
                        actionColor: _kAmber,
                      ),
                    ),
                  ],

                  // ── Leave room ────────────────────────────────────────────
                  if (active) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ActionCard(
                      icon: Icons.exit_to_app_rounded,
                      label: 'Leave Room',
                      subtitle: 'Your expenses and balances remain in history',
                      color: _kRed,
                      onTap: () => _confirm(
                        'Leave Room',
                        admin && room.memberIds.length > 1
                            ? 'Transfer admin responsibility to another active member before leaving.'
                            : room.memberIds.length == 1
                            ? 'You are the last member. Leaving will archive the room and preserve all records.'
                            : 'Leave active membership? Your previous expenses and balances remain accessible.',
                        'Leave',
                        () => service.leaveRoom(widget.roomId, userId),
                        leave: true,
                        actionColor: _kRed,
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

// ── _StatusBanner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _StatusBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.info_outline_rounded, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _InviteCodeCard ──────────────────────────────────────────────────────────

class _InviteCodeCard extends StatelessWidget {
  final String inviteCode;
  const _InviteCodeCard({required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: appCardDecoration(context, accentColor: _kTeal),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.vpn_key_rounded, size: 20, color: _kTeal),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite Code',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  inviteCode,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: _kTeal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy invite code',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kTeal.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.copy_rounded, size: 18, color: _kTeal),
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
            },
          ),
        ],
      ),
    );
  }
}

// ── _MemberTile ──────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final Color color;
  final bool dimmed;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _MemberTile({
    required this.name,
    required this.isAdmin,
    required this.color,
    this.dimmed = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dimmed
              ? (isDark ? 0.04 : 0.03)
              : (isDark ? 0.07 : 0.04)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: color.withValues(alpha: dimmed ? 0.08 : 0.14),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: dimmed ? 0.08 : 0.12),
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: dimmed ? 0.5 : 1.0),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: dimmed ? 0.45 : 0.9),
                    ),
                  ),
                  if (isAdmin || dimmed)
                    Text(
                      isAdmin ? 'Admin' : 'Former member',
                      style: TextStyle(
                        fontSize: 11,
                        color: isAdmin
                            ? color.withValues(alpha: 0.8)
                            : cs.onSurface.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ── _ActionCard ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.07 : 0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
