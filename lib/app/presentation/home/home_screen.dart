import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/room/providers/room_provider.dart';
import 'package:split_ex/modules/group/screens/groups_list_screen.dart';
import 'package:split_ex/modules/personal/presentation/dashboard/screens/personal_expense_tab.dart';
import 'package:split_ex/modules/project/screens/projects_list_screen.dart';
import 'package:split_ex/modules/room/screens/home/room_tab.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _processRecurring();
  }

  void _processRecurring() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = ref.read(authStateProvider).valueOrNull?.uid;
      if (userId != null) {
        ref.read(personalRecurringProcessorProvider).processRecurring(userId);
      }
    });
  }

  void _onNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final isDeveloper = ref.watch(isDeveloperProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final userName = profile?.name ?? 'User';

    return Scaffold(
      appBar: AppHeader(showDate: true, showHamburger: true, showNotification: true),
      drawer: _AppDrawer(userName: userName, userId: userId, isDeveloper: isDeveloper),
      body: GradientBody(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: [
            // Index 0: Personal Expenses
            const PersonalExpenseTab(key: ValueKey('personal')),

            // Index 1: Groups
            const GroupsListScreen(key: ValueKey('groups')),

            // Index 2: Room
            const RoomTab(key: ValueKey('room')),

            // Index 3: Projects
            const ProjectsListScreen(key: ValueKey('projects')),
          ][_selectedIndex],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final String userName;
  final String userId;
  final bool isDeveloper;
  const _AppDrawer({required this.userName, required this.userId, required this.isDeveloper});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
    final hasRoom = rooms.isNotEmpty;
    final firstRoom = hasRoom ? rooms.first : null;
    final isAdmin = firstRoom != null && firstRoom.isAdmin(userId);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.base),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: AppTextStyles.sectionHeader(context)),
                        Text('SplitEx', style: AppTextStyles.caption(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.divider(context), height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  if (firstRoom != null && isAdmin)
                    _DrawerTile(
                      icon: Icons.settings_outlined,
                      label: 'Room Settings',
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(currentRoomProvider.notifier).state = firstRoom;
                        context.push('/room/${firstRoom.id}/settings');
                      },
                    ),
                  if (isDeveloper && firstRoom != null)
                    _DrawerTile(
                      icon: Icons.storage_outlined,
                      label: 'DB & Storage',
                      subtitle: 'Developer only',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/room/${firstRoom.id}/storage');
                      },
                    ),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () { Navigator.pop(context); context.push('/notifications'); },
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () { Navigator.pop(context); context.push('/settings'); },
                  ),

                ],
              ),
            ),

            // Sign out at bottom
            Divider(color: AppColors.divider(context), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _DrawerTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                color: cs.error,
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authServiceProvider).signOut();
                  ref.invalidate(currentRoomProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  const _DrawerTile({required this.icon, required this.label, this.subtitle, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      leading: Icon(icon, size: 20, color: effectiveColor.withValues(alpha: onTap != null ? 0.75 : 0.4)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onTap != null ? effectiveColor : effectiveColor.withValues(alpha: 0.4),
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption(context))
          : null,
      onTap: onTap,
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  static const _items = [
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Personal'),
    (icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Groups'),
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Room'),
    (icon: Icons.track_changes_outlined, activeIcon: Icons.track_changes_rounded, label: 'Tracker'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / _items.length;
            return Container(
              height: 66,
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerHigh : cs.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.outline.withOpacity(isDark ? 0.15 : 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(isDark ? 0.15 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Sliding pill indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    left: itemWidth * selectedIndex + 8,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  // Nav items
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item = _items[i];
                      final selected = selectedIndex == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 66,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Glow dot above active icon
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  width: selected ? 4 : 0,
                                  height: selected ? 4 : 0,
                                  margin: EdgeInsets.only(bottom: selected ? 3 : 0),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: selected
                                        ? [BoxShadow(color: cs.primary.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)]
                                        : [],
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    selected ? item.activeIcon : item.icon,
                                    key: ValueKey(selected),
                                    size: 22,
                                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.4),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.4),
                                    letterSpacing: selected ? 0.2 : 0,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
