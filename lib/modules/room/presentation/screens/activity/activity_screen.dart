import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/domain/entities/activity_model.dart';
import 'package:split_ex/modules/room/presentation/providers/activity_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';

const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kBlue   = Color(0xFF3B82F6);
const _kTeal   = Color(0xFF14B8A6);
const _kPurple = Color(0xFF8B5CF6);
const _kSlate  = Color(0xFF64748B);

class ActivityScreen extends ConsumerWidget {
  final String roomId;
  final DateTime? selectedMonth;
  const ActivityScreen({super.key, required this.roomId, this.selectedMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesStreamProvider(roomId));
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final month = selectedMonth ?? DateTime.now();

    return Scaffold(
      appBar: AppHeader(
        showBack: true,
        title: DateFormat('MMM yyyy').format(month) == DateFormat('MMM yyyy').format(DateTime.now())
            ? 'Activity Log'
            : 'Activity · ${DateFormat('MMM yyyy').format(month)}',
        showNotification: false,
      ),
      body: GradientBody(
        child: activitiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allActivities) {
            final activities = allActivities
                .where((a) =>
                    a.createdAt.year == month.year &&
                    a.createdAt.month == month.month)
                .toList();
            if (activities.isEmpty) {
              return const AppEmptyState(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                subtitle: 'Actions in this room will appear here',
              );
            }

            final members = {
              ...?roomAsync.valueOrNull?.historicalMemberIds,
              for (final activity in activities) activity.performedBy,
            }.toList();
            final membersAsync = ref.watch(userProfilesByIdsProvider(members));
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
                final showDateSeparator =
                    index == 0 ||
                    !_isSameDay(
                      activities[index - 1].createdAt,
                      activity.createdAt,
                    );

                return Column(
                  children: [
                    if (showDateSeparator)
                      _DateSeparator(date: activity.createdAt),
                    _ActivityTile(activity: activity, nameMap: nameMap),
                  ],
                );
              },
            );
          },
        ),
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
    final cs = Theme.of(context).colorScheme;
    final isToday = _label() == 'Today';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isToday
                    ? cs.primary.withValues(alpha: .12)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _label(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: .55),
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant, thickness: 0.5)),
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
    ActivityType.expenseAdded      => Icons.add_circle_outline_rounded,
    ActivityType.expenseEdited     => Icons.edit_rounded,
    ActivityType.expenseDeleted    => Icons.delete_outline_rounded,
    ActivityType.settlementCreated  => Icons.payment_rounded,
    ActivityType.settlementConfirmed => Icons.check_circle_outline_rounded,
    ActivityType.memberJoined      => Icons.person_add_alt_1_rounded,
    ActivityType.memberLeft        => Icons.person_remove_alt_1_rounded,
    ActivityType.roomCreated       => Icons.home_rounded,
    ActivityType.roomSettingsChanged => Icons.settings_rounded,
    ActivityType.billAdded         => Icons.receipt_long_rounded,
    ActivityType.billEdited        => Icons.edit_note_rounded,
    ActivityType.billDeleted       => Icons.delete_sweep_rounded,
  };

  Color get _color => switch (activity.type) {
    ActivityType.expenseAdded      => _kGreen,
    ActivityType.expenseEdited     => _kBlue,
    ActivityType.expenseDeleted    => _kRed,
    ActivityType.settlementCreated  => _kAmber,
    ActivityType.settlementConfirmed => _kGreen,
    ActivityType.memberJoined      => _kTeal,
    ActivityType.memberLeft        => _kSlate,
    ActivityType.roomCreated       => _kPurple,
    ActivityType.roomSettingsChanged => _kAmber,
    ActivityType.billAdded         => _kGreen,
    ActivityType.billEdited        => _kBlue,
    ActivityType.billDeleted       => _kRed,
  };

  String _actionText() {
    final actor = nameMap[activity.performedBy] ?? activity.performedBy;
    final meta = activity.metadata;

    // If metadata exists, build rich text
    if (meta != null && meta.isNotEmpty) {
      final title = meta['title'] ?? '';
      final amount = meta['amount'];
      final amountStr = amount != null
          ? ' \u20B9${(amount as num).toStringAsFixed(0)}'
          : '';

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
              _detailRow(
                'Amount',
                '\u20B9${(amount as num).toStringAsFixed(2)}',
              ),
            _detailRow('Category', category),
            _detailRow('Paid by', paidByName),
            if (date.isNotEmpty) _detailRow('Date', date),
            if (splitNames.isNotEmpty) _detailRow('Split among', splitNames),
            if (splitAmount > 0)
              _detailRow(
                'Per person',
                '\u20B9${splitAmount.toStringAsFixed(2)}',
              ),
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
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(activity.createdAt);
    final hasDetails = activity.metadata != null && activity.metadata!.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color;

    return GestureDetector(
      onTap: hasDetails ? () => _showDetails(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: isDark ? .15 : .12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .08 : .03),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(_icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _actionText(),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: .45)),
                    ),
                  ],
                ),
              ),
              if (hasDetails)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Details',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
