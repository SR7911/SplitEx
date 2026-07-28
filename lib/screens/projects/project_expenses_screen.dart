import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/projects/add_project_expense_sheet.dart';

class ProjectExpensesScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String initialDebtFilter;
  const ProjectExpensesScreen({super.key, required this.projectId, this.initialDebtFilter = 'all'});

  @override
  ConsumerState<ProjectExpensesScreen> createState() => _ProjectExpensesScreenState();
}

enum _ProjectSortOption { timeDesc, timeAsc, amountDesc, amountAsc }

class _ProjectExpensesScreenState extends ConsumerState<ProjectExpensesScreen> {
  String _search = '';
  String? _categoryFilter;
  late String _debtFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _ProjectSortOption _sortOption = _ProjectSortOption.timeDesc;

  @override
  void initState() {
    super.initState();
    _debtFilter = widget.initialDebtFilter;
  }

  void _showFilterSheet(BuildContext context, List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProjectFilterBottomSheet(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        sortOption: _sortOption,
        onApply: (from, to, sort) {
          setState(() { _dateFrom = from; _dateTo = to; _sortOption = sort; });
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() { _dateFrom = null; _dateTo = null; _sortOption = _ProjectSortOption.timeDesc; });
          Navigator.pop(ctx);
        },
      ),
    );
  }

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
            if (_dateFrom != null && e.date.isBefore(_dateFrom!)) return false;
            if (_dateTo != null && e.date.isAfter(_dateTo!.add(const Duration(days: 1)))) return false;
            return true;
          }).toList();
          switch (_sortOption) {
            case _ProjectSortOption.timeDesc: filtered.sort((a, b) => b.date.compareTo(a.date));
            case _ProjectSortOption.timeAsc: filtered.sort((a, b) => a.date.compareTo(b.date));
            case _ProjectSortOption.amountDesc: filtered.sort((a, b) => b.amount.compareTo(a.amount));
            case _ProjectSortOption.amountAsc: filtered.sort((a, b) => a.amount.compareTo(b.amount));
          }

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
              // Debt filter chips + filter icon
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => _showFilterSheet(context, categories),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_dateFrom != null || _dateTo != null || _sortOption != _ProjectSortOption.timeDesc)
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune,
                          size: 20,
                          color: (_dateFrom != null || _dateTo != null || _sortOption != _ProjectSortOption.timeDesc)
                              ? Colors.white
                              : Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ),
                ],
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
    showViewProjectExpenseSheet(context, projectId: projectId, expense: expense);
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

class _ProjectFilterBottomSheet extends StatefulWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final _ProjectSortOption sortOption;
  final void Function(DateTime?, DateTime?, _ProjectSortOption) onApply;
  final VoidCallback onClear;

  const _ProjectFilterBottomSheet({
    required this.dateFrom,
    required this.dateTo,
    required this.sortOption,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_ProjectFilterBottomSheet> createState() => _ProjectFilterBottomSheetState();
}

class _ProjectFilterBottomSheetState extends State<_ProjectFilterBottomSheet> {
  late DateTime? _from;
  late DateTime? _to;
  late _ProjectSortOption _sort;

  @override
  void initState() {
    super.initState();
    _from = widget.dateFrom;
    _to = widget.dateTo;
    _sort = widget.sortOption;
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters & Sort', style: Theme.of(context).textTheme.titleMedium),
              TextButton(onPressed: widget.onClear, child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 12),
          Text('Date range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(_from != null ? DateFormat('dd MMM').format(_from!) : 'From'))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
              Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(_to != null ? DateFormat('dd MMM').format(_to!) : 'To'))),
              if (_from != null || _to != null)
                IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _from = null; _to = null; })),
            ],
          ),
          const SizedBox(height: 14),
          Text('Sort by', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Newest'), selected: _sort == _ProjectSortOption.timeDesc, onSelected: (_) => setState(() => _sort = _ProjectSortOption.timeDesc)),
              ChoiceChip(label: const Text('Oldest'), selected: _sort == _ProjectSortOption.timeAsc, onSelected: (_) => setState(() => _sort = _ProjectSortOption.timeAsc)),
              ChoiceChip(label: const Text('Amount ↑'), selected: _sort == _ProjectSortOption.amountAsc, onSelected: (_) => setState(() => _sort = _ProjectSortOption.amountAsc)),
              ChoiceChip(label: const Text('Amount ↓'), selected: _sort == _ProjectSortOption.amountDesc, onSelected: (_) => setState(() => _sort = _ProjectSortOption.amountDesc)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onApply(_from, _to, _sort),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
