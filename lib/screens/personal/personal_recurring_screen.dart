import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';

class PersonalRecurringScreen extends ConsumerWidget {
  const PersonalRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(personalRecurringProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurringSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: recurringAsync.when(
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
    );
  }

  void _showAddRecurringSheet(BuildContext context, WidgetRef ref) {
    String category = personalCategories.first;
    RecurringFrequency frequency = RecurringFrequency.monthly;
    int dayOfMonth = 1;
    DateTime? endDate;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                        Icon(Icons.repeat, color: Theme.of(ctx).colorScheme.primary, size: 24),
                        const SizedBox(width: 10),
                        Text('Add Recurring', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              filled: true,
                              fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: personalCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (v) => setSheetState(() => category = v!),
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<RecurringFrequency>(
                            value: frequency,
                            decoration: InputDecoration(
                              labelText: 'Frequency',
                              filled: true,
                              fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: RecurringFrequency.values.map((f) => DropdownMenuItem(value: f, child: Text(f.name, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (v) => setSheetState(() => frequency = v!),
                            isExpanded: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Day of month (1-31)',
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => dayOfMonth = int.tryParse(v) ?? 1,
                    ),
                    const SizedBox(height: 16),
                    // End date picker
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setSheetState(() => endDate = picked);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_busy, size: 18, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                endDate != null ? 'Ends: ${DateFormat('dd MMM yyyy').format(endDate!)}' : 'End date (optional)',
                                style: TextStyle(fontSize: 14, color: endDate != null ? null : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                              ),
                            ),
                            if (endDate != null)
                              GestureDetector(
                                onTap: () => setSheetState(() => endDate = null),
                                child: const Icon(Icons.close, size: 18, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text);
                        if (titleCtrl.text.isEmpty || amt == null || amt <= 0) return;
                        final userId = ref.read(authStateProvider).valueOrNull?.uid;
                        if (userId == null) return;

                        final recurring = RecurringTransaction(
                          id: '',
                          title: titleCtrl.text.trim(),
                          amount: amt,
                          category: category,
                          type: TransactionType.expense,
                          frequency: frequency,
                          dayOfMonth: dayOfMonth.clamp(1, 31),
                          active: true,
                          userId: userId,
                          endDate: endDate,
                        );
                        await ref.read(personalExpenseServiceProvider).addRecurring(userId, recurring);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Save Recurring', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPast ? Icons.history : (item.active ? Icons.autorenew_rounded : Icons.pause_circle_outline),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
    final r = item;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                Icon(Icons.repeat, color: isPast ? Colors.grey : Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Recurring Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: isPast ? Colors.grey : Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(icon: Icons.title, label: 'Title', value: r.title),
            _DetailRow(icon: Icons.currency_rupee, label: 'Amount', value: '₹${r.amount.toStringAsFixed(0)}'),
            _DetailRow(icon: Icons.category, label: 'Category', value: r.category),
            _DetailRow(icon: Icons.schedule, label: 'Frequency', value: r.frequency.name),
            _DetailRow(icon: Icons.calendar_today, label: 'Day', value: '${r.dayOfMonth}'),
            _DetailRow(icon: Icons.toggle_on, label: 'Status', value: isPast ? 'Expired' : (r.active ? 'Active' : 'Paused')),
            if (r.endDate != null)
              _DetailRow(icon: Icons.event_busy, label: 'End Date', value: DateFormat('dd MMM yyyy').format(r.endDate!)),
            if (r.lastRunDate != null)
              _DetailRow(icon: Icons.history, label: 'Last Run', value: DateFormat('dd MMM yyyy').format(r.lastRunDate!)),
            const SizedBox(height: 20),
            if (!isPast)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final userId = ref.read(authStateProvider).valueOrNull?.uid;
                        if (userId != null) {
                          await ref.read(personalExpenseServiceProvider).toggleRecurring(userId, r.id, !r.active);
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(r.active ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(r.active ? 'Pause' : 'Resume'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final userId = ref.read(authStateProvider).valueOrNull?.uid;
                        if (userId != null) {
                          await ref.read(personalExpenseServiceProvider).deleteRecurring(userId, r.id);
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
      ),
    );
  }
}

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
