import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/config/theme.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/theme_provider.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppHeader(showBack: true, title: 'Settings', showNotification: false),
      body: GradientBody(
        child: ListView(
          children: [
            // Profile card
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, 0),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.sm,
                  ),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      (profile?.name.isNotEmpty == true) ? profile!.name[0].toUpperCase() : 'U',
                      style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  title: Text(profile?.name ?? 'User', style: AppTextStyles.sectionHeader(context)),
                  subtitle: Text(profile?.email ?? '', style: AppTextStyles.caption(context)),
                  trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
                  onTap: () => context.push('/settings/edit-profile'),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Account & Security
            _SectionHeader('Account & Security'),
            _SettingsTile(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () => context.push('/settings/edit-profile'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () => context.push('/settings/change-password'),
            ),
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              label: 'Delete Account',
              color: cs.error,
              onTap: () => _confirmDeleteAccount(context, ref),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Preferences
            _SectionHeader('Preferences'),
            const _ThemeTile(),
            const _PaletteTile(),
            const _BodyGradientTile(),
            _SettingsTile(
              icon: Icons.currency_exchange_outlined,
              label: 'Default Currency',
              subtitle: '₹ INR',
              onTap: () => _showCurrencyPicker(context),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notification Preferences',
              onTap: () => context.push('/settings/notifications'),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Legal
            _SectionHeader('Legal'),
            _SettingsTile(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _openUrl(context, 'https://splitex.app/terms'),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _openUrl(context, 'https://splitex.app/privacy'),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Sign out
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: Icon(Icons.logout_rounded, color: cs.error),
                label: Text('Log Out', style: TextStyle(color: cs.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Version 1.0.0',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This will permanently delete your account and all associated data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authServiceProvider).deleteAccount();
                if (context.mounted) context.go('/login');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    // TODO: Implement currency selection with shared_preferences
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Currency selection coming soon')),
    );
  }

  void _openUrl(BuildContext context, String url) async {
    // Uses url_launcher — already in pubspec
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $url')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;
    return ListTile(
      leading: Icon(icon, size: 20, color: effectiveColor.withValues(alpha: 0.7)),
      title: Text(
        label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: effectiveColor),
      ),
      subtitle: subtitle != null ? Text(subtitle!, style: AppTextStyles.caption(context)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, ref),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
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
            onChanged: (value) {
              if (value == null) return;
              ref.read(themeModeProvider.notifier).setMode(value);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }
}

class _BodyGradientTile extends ConsumerWidget {
  const _BodyGradientTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(bodyGradientProvider);
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        Icons.gradient_rounded,
        size: 20,
        color: cs.onSurface.withValues(alpha: 0.7),
      ),
      title: const Text('Screen Body Gradient'),
      subtitle: Text(
        enabled ? 'Gradient fade below app bar' : 'Plain background',
        style: AppTextStyles.caption(context),
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (v) => ref.read(bodyGradientProvider.notifier).toggle(v),
      ),
    );
  }
}

class _PaletteTile extends ConsumerWidget {
  const _PaletteTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPalette = ref.watch(appPaletteProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_rounded, size: 22),
              const SizedBox(width: 16),
              Text(
                'Color - ${AppTheme.paletteName(currentPalette)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppPalette.values.map((palette) {
              final isSelected = palette == currentPalette;
              final color = AppTheme.paletteColor(palette);

              return Tooltip(
                message: AppTheme.paletteName(palette),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      ref.read(appPaletteProvider.notifier).setPalette(palette),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
