import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_entry.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_edit.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/presentation/recurring/providers/personal_recurring_providers.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/add_personal_transaction_screen.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';

/// Personal recurring entries backed by the domain repository.
class PersonalRecurringScreen extends ConsumerWidget {
  const PersonalRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(personalRecurringEntriesProvider);

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
            return const AppEmptyState(
              icon: Icons.repeat_rounded,
              title: 'No recurring transactions',
              subtitle: 'Automate your regular expenses',
            );
          }

          final active = items.where((r) => !r.isExpired).toList();
          final past = items.where((r) => r.isExpired).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                AppSectionHeader(title: 'Active (${active.length})', actionLabel: null, onAction: null),
                const SizedBox(height: 10),
                ...active.map((r) => _RecurringCard(item: r, isPast: false)),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 24),
                AppSectionHeader(title: 'Past (${past.length})', actionLabel: null, onAction: null),
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
  final PersonalRecurringEntry? existing;
  final WidgetRef ref;
  const _RecurringFormSheet({required this.existing, required this.ref});

  @override
  State<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<_RecurringFormSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late String _category;
  late PersonalRecurringFrequency _frequency;
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
    _frequency = e?.frequency ?? PersonalRecurringFrequency.monthly;
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
    return PersonalFormSheet(
      title: _isEdit ? 'Edit Recurring' : 'Add Recurring',
      icon: Icons.repeat_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildField(context, controller: _titleCtrl, label: 'Title', icon: Icons.title),
          const SizedBox(height: AppSpacing.md),
          _buildField(context, controller: _amountCtrl, label: 'Amount (₹)', icon: Icons.currency_rupee, isNumber: true),
          const SizedBox(height: AppSpacing.md),
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
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildDropdown<PersonalRecurringFrequency>(
                  context,
                  label: 'Frequency',
                  value: _frequency,
                  items: PersonalRecurringFrequency.values,
                  itemLabel: (v) => v.name,
                  onChanged: (v) => setState(() => _frequency = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDayField(context),
          const SizedBox(height: AppSpacing.md),
          _buildEndDatePicker(context),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEdit ? 'Save Changes' : 'Save Recurring'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, {required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildDropdown<T>(BuildContext context, {required String label, required T value, required List<T> items, required String Function(T) itemLabel, required ValueChanged<T?> onChanged}) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(itemLabel(v), style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildDayField(BuildContext context) {
    return TextFormField(
      initialValue: _dayOfMonth.toString(),
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Day of month (1–31)',
        prefixIcon: Icon(Icons.event_repeat_rounded, size: 18),
      ),
      onChanged: (v) => _dayOfMonth = int.tryParse(v) ?? _dayOfMonth,
    );
  }

  Widget _buildEndDatePicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.event_busy_outlined, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
      title: Text(
        _endDate != null ? 'Ends: ${DateFormat('dd MMM yyyy').format(_endDate!)}' : 'End date (optional)',
        style: TextStyle(fontSize: 14, color: _endDate != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5)),
      ),
      trailing: _endDate != null
          ? IconButton(
              icon: Icon(Icons.close, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
              onPressed: () => setState(() { _endDate = null; _clearEndDate = true; }),
            )
          : null,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _endDate ?? DateTime.now(),
          firstDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
          lastDate: DateTime(2035),
        );
        if (picked != null) setState(() { _endDate = picked; _clearEndDate = false; });
      },
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
      final userId = widget.ref.read(personalUserIdProvider).valueOrNull;
      if (userId == null) return;
      final repository = widget.ref.read(personalRecurringRepositoryProvider);

      if (_isEdit) {
        await repository.update(
          userId,
          widget.existing!,
          PersonalRecurringChanges(
            title: _titleCtrl.text.trim(),
            amount: amt,
            category: _category,
            frequency: _frequency,
            dayOfMonth: _dayOfMonth.clamp(1, 31),
            endDate: _endDate,
            clearEndDate: _clearEndDate,
          ),
        );
      } else {
        await repository.add(
          userId,
          PersonalRecurringEntry(
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
  final PersonalRecurringEntry item;
  final bool isPast;
  const _RecurringCard({required this.item, required this.isPast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final color = isPast
        ? cs.onSurface.withValues(alpha: 0.4)
        : (item.active ? AppColors.success(context) : AppColors.warning(context));
    final opacity = isPast ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppFinanceTile(
          onTap: () => _showDetailSheet(context, ref),
          icon: isPast
              ? Icons.history_rounded
              : (item.active ? Icons.autorenew_rounded : Icons.pause_circle_outline),
          color: color,
          title: item.title,
          subtitle: '${item.category} • ${item.frequency.name} • Day ${item.dayOfMonth}'
              '${item.endDate != null ? (isPast ? ' • Ended ${DateFormat('dd MMM yyyy').format(item.endDate!)}' : ' • Ends ${DateFormat('dd MMM yyyy').format(item.endDate!)}') : ''}',
          value: '₹${item.amount.toStringAsFixed(0)}',
          valueColor: color,
          badges: item.editHistory.isNotEmpty
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${item.editHistory.length} edit${item.editHistory.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.primary),
                      ),
                    ),
                  ],
                )
              : null,
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
  final PersonalRecurringEntry item;
  final bool isPast;
  final WidgetRef ref;
  const _RecurringDetailSheet({required this.item, required this.isPast, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isPast ? cs.onSurface.withValues(alpha: 0.4) : cs.primary;

    return PersonalFormSheet(
      title: 'Recurring Details',
      icon: Icons.repeat_rounded,
      trailing: !isPast
          ? IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
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
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      final userId = ref.read(personalUserIdProvider).valueOrNull;
                      if (userId != null) {
                        await ref.read(personalRecurringRepositoryProvider).toggle(userId, item.id, !item.active);
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(item.active ? Icons.pause : Icons.play_arrow, size: 18),
                    label: Text(item.active ? 'Pause' : 'Resume'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final userId = ref.read(personalUserIdProvider).valueOrNull;
                      if (userId != null) {
                        await ref.read(personalRecurringRepositoryProvider).delete(userId, item.id);
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                    label: Text('Delete', style: TextStyle(color: cs.error)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: cs.error)),
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
  final PersonalRecurringEdit snapshot;
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
        color: isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isLatest ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 14, color: isLatest ? const Color(0xFF3B82F6) : cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                isLatest ? 'Previous version' : 'Version ${total - index}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isLatest ? const Color(0xFF3B82F6) : cs.onSurface.withValues(alpha: 0.5)),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM yy, hh:mm a').format(snapshot.editedAt),
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
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
          Icon(icon, size: 11, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8))),
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
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
