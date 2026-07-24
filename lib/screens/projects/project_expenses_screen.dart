import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/projects/add_project_expense_sheet.dart';

class ProjectExpensesScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ProjectExpensesScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectExpensesScreen> createState() => _ProjectExpensesScreenState();
}

class _ProjectExpensesScreenState extends ConsumerState<ProjectExpensesScreen> {
  String _search = '';
  String? _categoryFilter;
  String _debtFilter = 'all'; // all, lent, borrowed, none

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(projectExpensesProvider(widget.projectId));
    final projectAsync = ref.watch(projectStreamProvider(widget.projectId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final project = projectAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(project != null ? '${project.name} • Expenses' : 'Expenses',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: project?.status != ProjectStatus.completed
          ? FloatingActionButton(
              onPressed: () => showAddProjectExpenseSheet(context, projectId: widget.projectId),
              child: const Icon(Icons.add),
            )
          : null,
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          final categories = expenses.map((e) => e.category).toSet().toList()..sort();

          var filtered = expenses.where((e) {
            if (_search.isNotEmpty && !e.title.toLowerCase().contains(_search.toLowerCase())) return false;
            if (_categoryFilter != null && e.category != _categoryFilter) return false;
            if (_debtFilter == 'lent' && e.debtType?.name != 'lent') return false;
            if (_debtFilter == 'borrowed' && e.debtType?.name != 'borrowed') return false;
            if (_debtFilter == 'none' && e.hasDebt) return false;
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 10),
              // Debt filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(label: 'All', selected: _debtFilter == 'all', onTap: () => setState(() => _debtFilter = 'all')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Lent', selected: _debtFilter == 'lent', color: Colors.green, onTap: () => setState(() => _debtFilter = 'lent')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Borrowed', selected: _debtFilter == 'borrowed', color: Colors.red, onTap: () => setState(() => _debtFilter = 'borrowed')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'No Debt', selected: _debtFilter == 'none', onTap: () => setState(() => _debtFilter = 'none')),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SizedBox(height: 32, child: VerticalDivider(width: 1, thickness: 1, indent: 4, endIndent: 4)),
                      const SizedBox(width: 8),
                      ...categories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: c,
                              selected: _categoryFilter == c,
                              onTap: () => setState(() => _categoryFilter = _categoryFilter == c ? null : c),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('${filtered.length} expenses', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                    const Spacer(),
                    Text(
                      'Total: ₹${filtered.fold(0.0, (s, e) => s + e.amount).toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            const Text('No expenses found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ExpenseCard(
                          expense: filtered[i],
                          projectId: widget.projectId,
                          isDark: isDark,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  final ProjectExpenseModel expense;
  final String projectId;
  final bool isDark;
  const _ExpenseCard({required this.expense, required this.projectId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final debtColor = expense.debtType?.name == 'lent' ? Colors.green : Colors.red;

    return GestureDetector(
      onTap: () => _showDetail(context, ref, uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: expense.hasDebt ? debtColor.withOpacity(0.1) : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                expense.hasDebt ? (expense.debtType?.name == 'lent' ? Icons.call_made : Icons.call_received) : Icons.receipt_long,
                size: 18,
                color: expense.hasDebt ? debtColor : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${expense.category} • ${DateFormat('dd MMM').format(expense.date)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                      if (expense.hasDebt) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: debtColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            expense.isSettled ? 'Settled' : (expense.debtType?.name == 'lent' ? 'Lent' : 'Borrowed'),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: expense.isSettled ? Colors.grey : debtColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (expense.personName != null)
                    Text(expense.personName!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${expense.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(expense.paymentMethod.name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseDetailSheet(expense: expense, projectId: projectId, uid: uid),
    );
  }
}

class _ExpenseDetailSheet extends ConsumerStatefulWidget {
  final ProjectExpenseModel expense;
  final String projectId;
  final String uid;
  const _ExpenseDetailSheet({required this.expense, required this.projectId, required this.uid});

  @override
  ConsumerState<_ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<_ExpenseDetailSheet> {
  bool _settling = false;

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Delete "${widget.expense.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(projectExpenseServiceProvider).deleteExpense(widget.uid, widget.projectId, widget.expense.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _settle() async {
    setState(() => _settling = true);
    await ref.read(projectExpenseServiceProvider).updateExpense(widget.uid, widget.projectId, widget.expense.id, {'isSettled': true});
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as settled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtColor = e.debtType?.name == 'lent' ? Colors.green : Colors.red;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                Icon(Icons.receipt_long, color: primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Expense Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: primary)),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showViewProjectExpenseSheet(context, projectId: widget.projectId, expense: e);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? primary.withOpacity(0.08) : primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  _DetailRow(icon: Icons.receipt_long, label: 'Title', value: e.title),
                  _DetailRow(icon: Icons.currency_rupee, label: 'Amount', value: '₹${e.amount.toStringAsFixed(0)}', valueColor: primary),
                  _DetailRow(icon: Icons.category, label: 'Category', value: e.category),
                  _DetailRow(icon: Icons.calendar_today, label: 'Date', value: DateFormat('dd MMM yyyy').format(e.date)),
                  _DetailRow(icon: Icons.payment, label: 'Payment', value: e.paymentMethod.name),
                  if (e.vendor != null) _DetailRow(icon: Icons.store_outlined, label: 'Vendor', value: e.vendor!),
                  if (e.hasDebt) ...[
                    _DetailRow(
                      icon: e.debtType?.name == 'lent' ? Icons.call_made : Icons.call_received,
                      label: 'Debt',
                      value: e.debtType?.name == 'lent' ? 'You Lent' : 'You Borrowed',
                      valueColor: debtColor,
                    ),
                    if (e.personName != null) _DetailRow(icon: Icons.person, label: 'Person', value: e.personName!),
                    _DetailRow(icon: Icons.check_circle_outline, label: 'Settled', value: e.isSettled ? 'Yes' : 'No'),
                  ],
                  if (e.notes != null && e.notes!.isNotEmpty) _DetailRow(icon: Icons.notes, label: 'Notes', value: e.notes!),
                ],
              ),
            ),
            if (e.hasDebt && !e.isSettled) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _settling ? null : _settle,
                icon: _settling ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                label: Text(e.debtType?.name == 'lent' ? 'Mark as Received' : 'Mark as Repaid'),
                style: FilledButton.styleFrom(
                  backgroundColor: debtColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
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
  final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

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
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : (isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
