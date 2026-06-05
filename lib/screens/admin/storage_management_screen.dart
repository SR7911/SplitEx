import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/services/storage_management_service.dart';

class StorageManagementScreen extends ConsumerStatefulWidget {
  final String roomId;
  const StorageManagementScreen({super.key, required this.roomId});

  @override
  ConsumerState<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends ConsumerState<StorageManagementScreen> {
  final _service = StorageManagementService();
  StorageStats? _stats;
  bool _loading = true;
  String? _actionMessage;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _loadStats();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth =>
      _selectedMonth.year == DateTime.now().year && _selectedMonth.month == DateTime.now().month;

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final userId = ref.read(currentUserIdProvider);
      final stats = await _service.getStats(widget.roomId, userId);
      setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _actionMessage = 'Failed: $e'; });
    }
  }

  Future<bool> _confirm(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  Future<void> _clearExpenses() async {
    if (!await _confirm('Clear Expenses', 'Delete all expenses for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearExpensesByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count expenses');
    _loadStats();
  }

  Future<void> _clearBills() async {
    if (!await _confirm('Clear Bills', 'Delete all bills for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearBillsByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count bills');
    _loadStats();
  }

  Future<void> _clearActivities() async {
    if (!await _confirm('Clear Activities', 'Delete all activity logs for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearActivitiesByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count activities');
    _loadStats();
  }

  Future<void> _clearSettlements() async {
    if (!await _confirm('Clear Settlements', 'Delete all settlements for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearSettlementsByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count settlements');
    _loadStats();
  }

  Future<void> _clearNotifications() async {
    final userId = ref.read(currentUserIdProvider);
    if (!await _confirm('Clear Notifications', 'Delete all notifications for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearNotificationsByMonth(userId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count notifications');
    _loadStats();
  }

  Future<void> _clearAllMonth() async {
    final userId = ref.read(currentUserIdProvider);
    if (!await _confirm('Clear All for $_monthKey', 'Delete ALL data (expenses, bills, activities, notifications) for $_monthKey? This cannot be undone.')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearAllDataByMonth(widget.roomId, userId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count total documents for $_monthKey');
    _loadStats();
  }

  Future<void> _clearImages() async {
    if (!await _confirm('Clear Images', 'Delete all receipt images? This cannot be undone.')) return;
    setState(() => _actionMessage = 'Deleting images...');
    final count = await _service.clearAllImages(widget.roomId);
    setState(() => _actionMessage = 'Deleted $count images');
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final monthData = _stats?.dataByMonth[_monthKey];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DB & Storage'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('Failed to load'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_actionMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_actionMessage!, style: const TextStyle(fontSize: 13))),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _actionMessage = null),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Overall stats
                    Text('Overall', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _StatRow('Expenses', '${_stats!.totalExpenses}'),
                            _StatRow('Bills', '${_stats!.totalBills}'),
                            _StatRow('Activities', '${_stats!.totalActivities}'),
                            _StatRow('Settlements', '${_stats!.totalSettlements}'),
                            _StatRow('Notifications', '${_stats!.totalNotifications}'),
                            _StatRow('Images', '${_stats!.totalImages}'),
                            const Divider(height: 16),
                            _StatRow('Total docs', '${_stats!.totalDocs}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Usage bars
                    Text('Usage & Limits', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _UsageBar(label: 'Daily Reads', used: _stats!.dailyReads, total: StorageStats.maxDailyReads, unit: 'hits'),
                            const SizedBox(height: 12),
                            _UsageBar(label: 'Daily Writes', used: _stats!.dailyWrites, total: StorageStats.maxDailyWrites, unit: 'hits'),
                            const SizedBox(height: 12),
                            _UsageBar(label: 'Firestore Data', used: _stats!.estimatedDocSizeBytes, total: StorageStats.maxFirestoreBytes, unit: 'bytes'),
                            const SizedBox(height: 12),
                            _UsageBar(label: 'Image Storage', used: _stats!.estimatedImageSizeBytes, total: StorageStats.maxStorageBytes, unit: 'bytes'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Month selector
                    Text('Month Data', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          // Month arrows
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                                Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                IconButton(icon: const Icon(Icons.chevron_right), onPressed: _isCurrentMonth ? null : _nextMonth),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          if (monthData == null || monthData.total == 0)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No data for this month', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  _MonthRow(label: 'Expenses', count: monthData.expenses, onClear: monthData.expenses > 0 ? _clearExpenses : null),
                                  _MonthRow(label: 'Bills', count: monthData.bills, onClear: monthData.bills > 0 ? _clearBills : null),
                                  _MonthRow(label: 'Activities', count: monthData.activities, onClear: monthData.activities > 0 ? _clearActivities : null),
                                  _MonthRow(label: 'Settlements', count: monthData.settlements, onClear: monthData.settlements > 0 ? _clearSettlements : null),
                                  _MonthRow(label: 'Notifications', count: monthData.notifications, onClear: monthData.notifications > 0 ? _clearNotifications : null),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total: ${monthData.total} docs', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      TextButton.icon(
                                        onPressed: _clearAllMonth,
                                        icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                                        label: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Images
                    Text('Images', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.image),
                        title: Text('${_stats!.totalImages} receipt images'),
                        subtitle: Text('~${_formatSize(_stats!.estimatedImageSizeBytes)}'),
                        trailing: TextButton.icon(
                          onPressed: _stats!.totalImages > 0 ? _clearImages : null,
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Limits reference
                    Card(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Firebase Free Tier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            SizedBox(height: 8),
                            Text('• 50K reads / 20K writes per day', style: TextStyle(fontSize: 12)),
                            Text('• 1 GiB Firestore storage', style: TextStyle(fontSize: 12)),
                            Text('• 5 GB file storage', style: TextStyle(fontSize: 12)),
                            Text('• 1 GB/day download bandwidth', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onClear;
  const _MonthRow({required this.label, required this.count, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: onClear != null
                ? TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                    child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int used;
  final int total;
  final String unit;
  const _UsageBar({required this.label, required this.used, required this.total, required this.unit});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  String _formatCount(int count) {
    if (count < 1000) return '$count';
    return '${(count / 1000).toStringAsFixed(1)}K';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final remaining = (total - used).clamp(0, total);
    final isBytes = unit == 'bytes';
    final usedStr = isBytes ? _formatSize(used) : _formatCount(used);
    final totalStr = isBytes ? _formatSize(total) : _formatCount(total);
    final remainStr = isBytes ? _formatSize(remaining) : _formatCount(remaining);
    final color = ratio < 0.7 ? Colors.green : ratio < 0.9 ? Colors.orange : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('$remainStr free', style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ratio, backgroundColor: Colors.grey.withOpacity(0.2), color: color, minHeight: 6),
        ),
        const SizedBox(height: 2),
        Text('$usedStr / $totalStr', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}
