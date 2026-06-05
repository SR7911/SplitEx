import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account & Security
          _SectionHeader('Account & Security'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            subtitle: Text(profile?.name ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/edit-profile'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/change-password'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account',
                style: TextStyle(color: Colors.red)),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),

          const Divider(),

          // Preferences
          _SectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Default Currency'),
            subtitle: const Text('₹ INR'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencyPicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification Preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),

          const Divider(),

          // Legal
          _SectionHeader('Legal'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(context, 'https://splitex.app/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(context, 'https://splitex.app/privacy'),
          ),

          const Divider(),

          // Session
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),

          // App version
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
