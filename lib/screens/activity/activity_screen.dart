import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/providers/activity_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

class ActivityScreen extends ConsumerWidget {
  final String roomId;
  const ActivityScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesStreamProvider(roomId));
    final roomAsync = ref.watch(roomStreamProvider(roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (activities) {
          if (activities.isEmpty) {
            return const Center(child: Text('No activity yet'));
          }

          final members = roomAsync.valueOrNull?.memberIds ?? [];
          final membersAsync = ref.watch(roomMembersProvider(members));
          final nameMap = <String, String>{};
          if (membersAsync.hasValue) {
            for (final m in membersAsync.value!) {
              nameMap[m.uid] = m.name;
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final showDateSeparator = index == 0 ||
                  !_isSameDay(activities[index - 1].createdAt, activity.createdAt);

              return Column(
                children: [
                  if (showDateSeparator)
                    _DateSeparator(date: activity.createdAt),
                  _ActivityTile(
                    activity: activity,
                    nameMap: nameMap,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[400], thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(),
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[400], thickness: 0.5)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityModel activity;
  final Map<String, String> nameMap;
  const _ActivityTile({required this.activity, required this.nameMap});

  IconData get _icon => switch (activity.type) {
        ActivityType.expenseAdded => Icons.add_circle,
        ActivityType.expenseEdited => Icons.edit,
        ActivityType.expenseDeleted => Icons.delete,
        ActivityType.settlementCreated => Icons.payment,
        ActivityType.settlementConfirmed => Icons.check_circle,
        ActivityType.memberJoined => Icons.person_add,
        ActivityType.memberLeft => Icons.person_remove,
        ActivityType.roomCreated => Icons.home,
        ActivityType.roomSettingsChanged => Icons.settings,
        ActivityType.billAdded => Icons.add_circle_outline,
        ActivityType.billEdited => Icons.edit,
        ActivityType.billDeleted => Icons.delete_outline,
      };

  Color get _color => switch (activity.type) {
        ActivityType.expenseAdded => Colors.green,
        ActivityType.expenseEdited => Colors.blue,
        ActivityType.expenseDeleted => Colors.red,
        ActivityType.settlementCreated => Colors.orange,
        ActivityType.settlementConfirmed => Colors.green,
        ActivityType.memberJoined => Colors.teal,
        ActivityType.memberLeft => Colors.grey,
        ActivityType.roomCreated => Colors.purple,
        ActivityType.roomSettingsChanged => Colors.amber,
        ActivityType.billAdded => Colors.green,
        ActivityType.billEdited => Colors.blue,
        ActivityType.billDeleted => Colors.red,
      };

  String _actionText() {
    final actor = nameMap[activity.performedBy] ?? activity.performedBy;
    final meta = activity.metadata;

    // If metadata exists, build rich text
    if (meta != null && meta.isNotEmpty) {
      final title = meta['title'] ?? '';
      final amount = meta['amount'];
      final amountStr = amount != null ? ' ₹${(amount as num).toStringAsFixed(0)}' : '';

      return switch (activity.type) {
        ActivityType.expenseAdded => '$actor added "$title"$amountStr',
        ActivityType.expenseEdited => '$actor edited "$title"$amountStr',
        ActivityType.expenseDeleted => '$actor deleted "$title"$amountStr',
        _ => '$actor • ${activity.description}',
      };
    }

    // Fallback to stored description
    return '$actor • ${activity.description}';
  }

  void _showDetails(BuildContext context) {
    final meta = activity.metadata;
    if (meta == null || meta.isEmpty) return;

    final title = meta['title'] ?? 'N/A';
    final amount = meta['amount'];
    final category = meta['category'] ?? 'N/A';
    final paidBy = meta['paidBy'] ?? '';
    final splitAmong = (meta['splitAmong'] as List?)?.cast<String>() ?? [];
    final date = meta['date'] ?? '';
    final paidByName = nameMap[paidBy] ?? paidBy;
    final splitNames = splitAmong.map((id) => nameMap[id] ?? id).join(', ');
    final splitAmount = (amount != null && splitAmong.isNotEmpty)
        ? (amount as num) / splitAmong.length
        : 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (amount != null)
              _detailRow('Amount', '₹${(amount as num).toStringAsFixed(2)}'),
            _detailRow('Category', category),
            _detailRow('Paid by', paidByName),
            if (date.isNotEmpty) _detailRow('Date', date),
            if (splitNames.isNotEmpty) _detailRow('Split among', splitNames),
            if (splitAmount > 0)
              _detailRow('Per person', '₹${splitAmount.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('dd MMM, hh:mm a').format(activity.createdAt);
    final hasDetails = activity.metadata != null && activity.metadata!.isNotEmpty;

    return InkWell(
      onTap: hasDetails ? () => _showDetails(context) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _color.withOpacity(0.15),
                child: Icon(_icon, size: 18, color: _color),
              ),
              Container(width: 2, height: 40, color: Colors.grey[300]),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _actionText(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  if (hasDetails)
                    Text(
                      'Tap for details',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
