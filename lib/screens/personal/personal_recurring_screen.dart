import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';
import 'package:split_ex/widgets/app_header.dart';

class PersonalRecurringScreen extends ConsumerWidget {
  const PersonalRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(personalRecurringProvider);

    return Scaffold(
      appBar: const AppHeader(showBack: true, title: 'Recurring Transactions', showNotification: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurringSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: GradientBody(
        child: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No recurring transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Automate your regular expenses', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }

          final active = items.where((r) => !r.isExpired).toList();
          final past = items.where((r) => r.isExpired).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                const Text('Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                ...active.map((r) => _RecurringCard(item: r, isPast: false)),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Past', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey.shade500)),
                const SizedBox(height: 10),
                ...past.map((r) => _RecurringCard(item: r, isPast: true)),
              ],
            ],
          );
        },
      ),
      ),
    );
  }

  void _showAddRecurringSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringFormSheet(existing: null, ref: ref),
    );
  }
}

// ── Shared form sheet (add + edit) ────────────────────────────────────────

class _RecurringFormSheet extends StatefulWidget {
  final RecurringTransaction? existing;
  final WidgetRef ref;
  const _RecurringFormSheet({required this.existing, required this.ref});

  @override
  State<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<_RecurringFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late String _category;
  late RecurringFrequency _frequency;
  late int _dayOfMonth;
  DateTime? _endDate;
  bool _clearEndDate = false;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _category = e?.category ?? personalCategories.first;
    _frequency = e?.frequency ?? RecurringFrequency.monthly;
    _dayOfMonth = e?.dayOfMonth ?? 1;
    _endDate = e?.endDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48, height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.repeat, color: cs.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _isEdit ? 'Edit Recurring' : 'Add Recurring',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildField(context, controller: _titleCtrl, label: 'Title', icon: Icons.title),
              const SizedBox(height: 14),
              _buildField(context, controller: _amountCtrl, label: 'Amount (₹)', icon: Icons.currency_rupee, isNumber: true),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String>(
                      context,
                      label: 'Category',
                      value: _category,
                      items: personalCategories,
                      itemLabel: (v) => v,
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown<RecurringFrequency>(
                      context,
                      label: 'Frequency',
                      value: _frequency,
                      items: RecurringFrequency.values,
                      itemLabel: (v) => v.name,
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDayField(context),
              const SizedBox(height: 14),
              _buildEndDatePicker(context),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Save Changes' : 'Save Recurring', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, {required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown<T>(BuildContext context, {required String label, required T value, required List<T> items, required String Function(T) itemLabel, required ValueChanged<T?> onChanged}) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(itemLabel(v), style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildDayField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      initialValue: _dayOfMonth.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Day of month (1–31)',
        prefixIcon: const Icon(Icons.event_repeat_rounded, size: 18),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      onChanged: (v) => _dayOfMonth = int.tryParse(v) ?? _dayOfMonth,
    );
  }

  Widget _buildEndDatePicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _endDate ?? DateTime.now(),
          firstDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
          lastDate: DateTime(2035),
        );
        if (picked != null) setState(() { _endDate = picked; _clearEndDate = false; });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.event_busy, size: 18, color: cs.onSurface.withOpacity(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _endDate != null ? 'Ends: ${DateFormat('dd MMM yyyy').format(_endDate!)}' : 'End date (optional)',
                style: TextStyle(fontSize: 14, color: _endDate != null ? null : cs.onSurface.withOpacity(0.5)),
              ),
            ),
            if (_endDate != null)
              GestureDetector(
                onTap: () => setState(() { _endDate = null; _clearEndDate = true; }),
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountCtrl.text);
    if (_titleCtrl.text.trim().isEmpty || amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill title and amount')));
      return;
    }
    setState(() => _loading = true);
    try {
      final userId = widget.ref.read(authStateProvider).valueOrNull?.uid;
      if (userId == null) return;
      final service = widget.ref.read(personalExpenseServiceProvider);

      if (_isEdit) {
        await service.updateRecurring(
          userId,
          widget.existing!,
          title: _titleCtrl.text.trim(),
          amount: amt,
          category: _category,
          frequency: _frequency,
          dayOfMonth: _dayOfMonth.clamp(1, 31),
          endDate: _endDate,
          clearEndDate: _clearEndDate,
        );
      } else {
        await service.addRecurring(
          userId,
          RecurringTransaction(
            id: '',
            title: _titleCtrl.text.trim(),
            amount: amt,
            category: _category,
            type: TransactionType.expense,
            frequency: _frequency,
            dayOfMonth: _dayOfMonth.clamp(1, 31),
            active: true,
            userId: userId,
            endDate: _endDate,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Recurring card ────────────────────────────────────────────────────────

class _RecurringCard extends ConsumerWidget {
  final RecurringTransaction item;
  final bool isPast;
  const _RecurringCard({required this.item, required this.isPast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isPast ? Colors.grey : (item.active ? Colors.green : Colors.orange);
    final opacity = isPast ? 0.5 : 1.0;

    return GestureDetector(
      onTap: () => _showDetailSheet(context, ref),
      child: Opacity(
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  isPast ? Icons.history : (item.active ? Icons.autorenew_rounded : Icons.pause_circle_outline),
                  color: color, size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        if (item.editHistory.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('${item.editHistory.length} edit${item.editHistory.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.blue)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category} • ${item.frequency.name} • Day ${item.dayOfMonth}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    ),
                    if (item.endDate != null)
                      Text(
                        isPast ? 'Ended: ${DateFormat('dd MMM yyyy').format(item.endDate!)}' : 'Ends: ${DateFormat('dd MMM yyyy').format(item.endDate!)}',
                        style: TextStyle(fontSize: 10, color: isPast ? Colors.grey : Colors.orange),
                      ),
                  ],
                ),
              ),
              Text('₹${item.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isPast ? Colors.grey : null)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringDetailSheet(item: item, isPast: isPast, ref: ref),
    );
  }
}

// ── Detail sheet ──────────────────────────────────────────────────────────

class _RecurringDetailSheet extends StatelessWidget {
  final RecurringTransaction item;
  final bool isPast;
  final WidgetRef ref;
  const _RecurringDetailSheet({required this.item, required this.isPast, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isPast ? Colors.grey : cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: Container(
              width: 48, height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Row(
            children: [
              Icon(Icons.repeat, color: color, size: 24),
              const SizedBox(width: 10),
              Text('Recurring Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color)),
              const Spacer(),
              if (!isPast)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: cs.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _RecurringFormSheet(existing: item, ref: ref),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(icon: Icons.title, label: 'Title', value: item.title),
          _DetailRow(icon: Icons.currency_rupee, label: 'Amount', value: '₹${item.amount.toStringAsFixed(0)}'),
          _DetailRow(icon: Icons.category, label: 'Category', value: item.category),
          _DetailRow(icon: Icons.schedule, label: 'Frequency', value: item.frequency.name),
          _DetailRow(icon: Icons.calendar_today, label: 'Day', value: '${item.dayOfMonth}'),
          _DetailRow(icon: Icons.toggle_on, label: 'Status', value: isPast ? 'Expired' : (item.active ? 'Active' : 'Paused')),
          if (item.endDate != null)
            _DetailRow(icon: Icons.event_busy, label: 'End Date', value: DateFormat('dd MMM yyyy').format(item.endDate!)),
          if (item.lastRunDate != null)
            _DetailRow(icon: Icons.history, label: 'Last Run', value: DateFormat('dd MMM yyyy').format(item.lastRunDate!)),

          // ── Edit history ──
          if (item.editHistory.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.manage_history_rounded, size: 16, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text('Edit History (${item.editHistory.length})', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface.withOpacity(0.7))),
              ],
            ),
            const SizedBox(height: 12),
            ...item.editHistory.asMap().entries.map((entry) {
              final idx = entry.key;
              final snap = entry.value;
              final isLatest = idx == 0;
              return _EditHistoryTile(snapshot: snap, index: idx, total: item.editHistory.length, isLatest: isLatest);
            }),
          ],

          const SizedBox(height: 20),
          if (!isPast)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final userId = ref.read(authStateProvider).valueOrNull?.uid;
                      if (userId != null) {
                        await ref.read(personalExpenseServiceProvider).toggleRecurring(userId, item.id, !item.active);
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(item.active ? Icons.pause : Icons.play_arrow, size: 18),
                    label: Text(item.active ? 'Pause' : 'Resume'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final userId = ref.read(authStateProvider).valueOrNull?.uid;
                      if (userId != null) {
                        await ref.read(personalExpenseServiceProvider).deleteRecurring(userId, item.id);
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Edit history tile ─────────────────────────────────────────────────────

class _EditHistoryTile extends StatelessWidget {
  final RecurringEditSnapshot snapshot;
  final int index;
  final int total;
  final bool isLatest;
  const _EditHistoryTile({required this.snapshot, required this.index, required this.total, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest.withOpacity(0.5) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLatest ? Colors.blue.withOpacity(0.3) : cs.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 14, color: isLatest ? Colors.blue : cs.onSurface.withOpacity(0.4)),
              const SizedBox(width: 6),
              Text(
                isLatest ? 'Previous version' : 'Version ${total - index}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isLatest ? Colors.blue : cs.onSurface.withOpacity(0.5)),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM yy, hh:mm a').format(snapshot.editedAt),
                style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.4)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SnapChip(label: snapshot.title, icon: Icons.title),
              _SnapChip(label: '₹${snapshot.amount.toStringAsFixed(0)}', icon: Icons.currency_rupee),
              _SnapChip(label: snapshot.category, icon: Icons.category_outlined),
              _SnapChip(label: snapshot.frequency.name, icon: Icons.repeat),
              _SnapChip(label: 'Day ${snapshot.dayOfMonth}', icon: Icons.calendar_today_outlined),
              if (snapshot.endDate != null)
                _SnapChip(label: 'Ends ${DateFormat('dd MMM yy').format(snapshot.endDate!)}', icon: Icons.event_busy_outlined),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SnapChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.8))),
        ],
      ),
    );
  }
}

// ── Shared detail row ─────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
