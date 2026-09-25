import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/providers/notification_provider.dart';
import 'package:split_ex/providers/theme_provider.dart';
import 'package:split_ex/widgets/offline_banner.dart';
import 'package:split_ex/widgets/design_system/app_spacing.dart';

/// Wraps a screen body continuing the app bar gradient fade.
/// Respects the [bodyGradientProvider] toggle — when disabled, renders
/// the child directly with no gradient overlay.
class GradientBody extends ConsumerWidget {
  final Widget child;
  const GradientBody({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(bodyGradientProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final bg      = Theme.of(context).scaffoldBackgroundColor;

    // When disabled: only a short top-seam fade (matches AppBar bottom alpha)
    // so the AppBar gradient doesn't hard-cut into the plain body.
    // When enabled: full gradient fade down the screen body.
    final gradientColors = enabled
        ? [
            primary.withValues(alpha: 0.18),
            primary.withValues(alpha: 0.04),
            bg,
          ]
        : [
            primary.withValues(alpha: 0.18),
            primary.withValues(alpha: 0.0),
          ];
    final gradientStops = enabled
        ? const [0.0, 0.25, 1.0]
        : const [0.0, 0.12];

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: gradientStops,
                colors: gradientColors,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A reusable app header that sits on the scaffold background (not solid primary).
///
/// - [showDate] = true  → shows formatted date in center
/// - [showDate] = false → shows [title] in center
/// - [showHamburger] = true → opens drawer
/// - [showBack] = true  → shows back arrow
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool showDate;
  final String? title;
  final bool showHamburger;
  final bool showBack;
  final bool showNotification;

  const AppHeader({
    super.key,
    this.showDate = false,
    this.title,
    this.showHamburger = false,
    this.showBack = false,
    this.showNotification = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _formattedDate() {
    final now = DateTime.now();
    final suffix = _daySuffix(now.day);
    return '${now.day}$suffix ${DateFormat('MMM yyyy, EEE').format(now)}';
  }

  String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    // Status bar adapts to the scaffold background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    final centerText = showDate ? _formattedDate() : (title ?? '');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 1.0],
          colors: [
            cs.primary.withValues(alpha: isDark ? 0.55 : 0.45),
            cs.primary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Row(
              children: [
                // Left action
                Builder(
                  builder: (ctx) => _HeaderIconButton(
                    icon: showBack
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.menu_rounded,
                    onTap: () {
                      if (showBack) {
                        context.pop();
                      } else {
                        Scaffold.of(ctx).openDrawer();
                      }
                    },
                  ),
                ),

                // Center
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const OfflineIndicator(),
                      Flexible(
                        child: Text(
                          centerText,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right action
                if (showNotification)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _HeaderIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: () => context.push('/notifications'),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.75)),
      ),
    );
  }
}
