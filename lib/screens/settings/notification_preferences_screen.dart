import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.receipt_long),
            title: const Text('New Expenses'),
            subtitle: const Text('When someone adds an expense'),
            value: _pushExpenses,
            onChanged: (v) {
              setState(() => _pushExpenses = v);
              _save('notif_expenses', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('Payment Reminders'),
            subtitle: const Text('When someone nudges you to pay'),
            value: _pushReminders,
            onChanged: (v) {
              setState(() => _pushReminders = v);
              _save('notif_reminders', v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.check_circle_outline),
            title: const Text('Settlements'),
            subtitle: const Text('When a payment is confirmed'),
            value: _pushSettlements,
            onChanged: (v) {
              setState(() => _pushSettlements = v);
              _save('notif_settlements', v);
            },
          ),
        ],
      ),
    );
  }
}
