import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _pushExpenses = true;
  bool _pushReminders = true;
  bool _pushSettlements = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushExpenses = prefs.getBool('notif_expenses') ?? true;
      _pushReminders = prefs.getBool('notif_reminders') ?? true;
      _pushSettlements = prefs.getBool('notif_settlements') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AppHeader(
        showBack: true,
        title: 'Notification Preferences',
        showNotification: false,
      ),
      body: GradientBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            Container(
              decoration: appCardDecoration(context),
              child: Column(
                children: [
                  _PrefTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'New Expenses',
                    subtitle: 'When someone adds an expense',
                    value: _pushExpenses,
                    onChanged: (v) {
                      setState(() => _pushExpenses = v);
                      _save('notif_expenses', v);
                    },
                  ),
                  Divider(height: 1, color: cs.outline.withValues(alpha: .08)),
                  _PrefTile(
                    icon: Icons.alarm_outlined,
                    title: 'Payment Reminders',
                    subtitle: 'When someone nudges you to pay',
                    value: _pushReminders,
                    onChanged: (v) {
                      setState(() => _pushReminders = v);
                      _save('notif_reminders', v);
                    },
                  ),
                  Divider(height: 1, color: cs.outline.withValues(alpha: .08)),
                  _PrefTile(
                    icon: Icons.check_circle_outline,
                    title: 'Settlements',
                    subtitle: 'When a payment is confirmed',
                    value: _pushSettlements,
                    onChanged: (v) {
                      setState(() => _pushSettlements = v);
                      _save('notif_settlements', v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 18, color: cs.primary),
      ),
      title: Text(title, style: AppTextStyles.body(context)),
      subtitle: Text(subtitle, style: AppTextStyles.caption(context)),
      value: value,
      onChanged: onChanged,
    );
  }
}
