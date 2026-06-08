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

  /// Shows confirmation dialog, then a 10-second countdown with cancel option.
  /// Returns true only if user confirms AND doesn't cancel during countdown.
  Future<bool> _confirmWithCountdown(String title, String content) async {
    // Step 1: Confirmation dialog
    final confirmed = await showDialog<bool>(
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

    if (!confirmed || !mounted) return false;

    // Step 2: 10-second countdown with cancel
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDialog(title: title),
    ) ?? false;

    return proceed;
  }

  Future<void> _clearExpenses() async {
    if (!await _confirmWithCountdown('Clear Expenses', 'Delete all room expenses for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearExpensesByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count expenses');
    _loadStats();
  }

  Future<void> _clearBills() async {
    if (!await _confirmWithCountdown('Clear Bills', 'Delete all bills for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearBillsByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count bills');
    _loadStats();
  }

  Future<void> _clearActivities() async {
    if (!await _confirmWithCountdown('Clear Activities', 'Delete all activity logs for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearActivitiesByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count activities');
    _loadStats();
  }

  Future<void> _clearSettlements() async {
    if (!await _confirmWithCountdown('Clear Settlements', 'Delete all settlements for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearSettlementsByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count settlements');
    _loadStats();
  }

  Future<void> _clearNotifications() async {
    if (!await _confirmWithCountdown('Clear Notifications', 'Delete ALL notifications for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearNotificationsByMonth(_monthKey);
    setState(() => _actionMessage = 'Deleted $count notifications');
    _loadStats();
  }

  Future<void> _clearPersonalTxns() async {
    if (!await _confirmWithCountdown('Clear Personal Transactions', 'Delete ALL users\' personal transactions for $_monthKey?')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearPersonalTransactionsByMonth(_monthKey);
    setState(() => _actionMessage = 'Deleted $count personal transactions');
    _loadStats();
  }

  Future<void> _clearAllMonth() async {
    if (!await _confirmWithCountdown('Clear All for $_monthKey', 'Delete ALL data for $_monthKey? This cannot be undone.')) return;
    setState(() => _actionMessage = 'Deleting...');
    final count = await _service.clearAllDataByMonth(widget.roomId, _monthKey);
    setState(() => _actionMessage = 'Deleted $count total documents');
    _loadStats();
  }

  Future<void> _clearImages() async {
    if (!await _confirmWithCountdown('Clear Images', 'Delete all receipt images? This cannot be undone.')) return;
    setState(() => _actionMessage = 'Deleting images...');
    final count = await _service.clearAllImages(widget.roomId);
    setState(() => _actionMessage = 'Deleted $count images');
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final monthData = _stats?.dataByMonth[_monthKey];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Admin'),
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
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_actionMessage!, style: const TextStyle(fontSize: 12))),
                            GestureDetector(
                              onTap: () => setState(() => _actionMessage = null),
                              child: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ─── Overall Summary ───
                    _SectionHeader(icon: Icons.storage, title: 'Firebase Overview'),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _StatPill(label: 'Users', value: '${_stats!.totalUsers}', color: Colors.blue, isDark: isDark),
                                const SizedBox(width: 8),
                                _StatPill(label: 'Documents', value: '${_stats!.totalDocs}', color: Colors.purple, isDark: isDark),
                                const SizedBox(width: 8),
                                _StatPill(label: 'Images', value: '${_stats!.totalImages}', color: Colors.orange, isDark: isDark),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            _StatRow('Room Expenses', '${_stats!.totalExpenses}'),
                            _StatRow('Room Bills', '${_stats!.totalBills}'),
                            _StatRow('Activities', '${_stats!.totalActivities}'),
                            _StatRow('Settlements', '${_stats!.totalSettlements}'),
                            _StatRow('Notifications', '${_stats!.totalNotifications}'),
                            const Divider(height: 16),
                            _StatRow('Personal Transactions', '${_stats!.totalPersonalTransactions}'),
                            _StatRow('Personal Budgets', '${_stats!.totalPersonalBudgets}'),
                            _StatRow('Personal Recurring', '${_stats!.totalPersonalRecurring}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Estimated Usage (this device) ───
                    _SectionHeader(icon: Icons.speed, title: 'Estimated Usage (this device)'),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _UsageBar(label: 'Daily Reads', used: _stats!.dailyReads, total: StorageStats.maxDailyReads, unit: 'hits'),
                            const SizedBox(height: 14),
                            _UsageBar(label: 'Daily Writes', used: _stats!.dailyWrites, total: StorageStats.maxDailyWrites, unit: 'hits'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Project Storage ───
                    _SectionHeader(icon: Icons.cloud, title: 'Project Storage'),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _UsageBar(label: 'Firestore Data', used: _stats!.estimatedDocSizeBytes, total: StorageStats.maxFirestoreBytes, unit: 'bytes'),
                            const SizedBox(height: 14),
                            _UsageBar(label: 'Image Storage', used: _stats!.estimatedImageSizeBytes, total: StorageStats.maxStorageBytes, unit: 'bytes'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Month Data ───
                    _SectionHeader(icon: Icons.calendar_month, title: 'Month Data'),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                                Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                                  _MonthRow(label: 'Room Expenses', count: monthData.expenses, onClear: monthData.expenses > 0 ? _clearExpenses : null),
                                  _MonthRow(label: 'Bills', count: monthData.bills, onClear: monthData.bills > 0 ? _clearBills : null),
                                  _MonthRow(label: 'Activities', count: monthData.activities, onClear: monthData.activities > 0 ? _clearActivities : null),
                                  _MonthRow(label: 'Settlements', count: monthData.settlements, onClear: monthData.settlements > 0 ? _clearSettlements : null),
                                  _MonthRow(label: 'Notifications', count: monthData.notifications, onClear: monthData.notifications > 0 ? _clearNotifications : null),
                                  _MonthRow(label: 'Personal Txns', count: monthData.personalTransactions, onClear: monthData.personalTransactions > 0 ? _clearPersonalTxns : null),
                                  _MonthRow(label: 'Personal Budgets', count: monthData.personalBudgets, onClear: null),
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

                    // ─── Images ───
                    _SectionHeader(icon: Icons.image, title: 'Image Storage'),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.photo_library, color: Colors.orange),
                        ),
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

                    // ─── Firebase Limits ───
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDark ? Colors.blue.withOpacity(0.08) : Colors.blue.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Firebase Free Tier Limits', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Theme.of(context).colorScheme.primary)),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _StatPill({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            Text('$remainStr free', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ratio, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, color: color, minHeight: 6),
        ),
        const SizedBox(height: 2),
        Text('$usedStr / $totalStr', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

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
}

class _CountdownDialog extends StatefulWidget {
  final String title;
  const _CountdownDialog({required this.title});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _remaining = 10;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();

    _controller.addListener(() {
      final newRemaining = (10 - (_controller.value * 10)).ceil();
      if (newRemaining != _remaining) {
        setState(() => _remaining = newRemaining);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Deleting in...', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: 1 - _controller.value,
                  strokeWidth: 4,
                  color: Colors.red,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              Text(
                '$_remaining',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Press Cancel to abort',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, false),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}
