import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';
import 'package:split_ex/screens/personal/view_personal_transaction_sheet.dart';

class PersonalTransactionsScreen extends ConsumerStatefulWidget {
  final String monthKey;
  const PersonalTransactionsScreen({super.key, required this.monthKey});

  @override
  ConsumerState<PersonalTransactionsScreen> createState() => _PersonalTransactionsScreenState();
}

enum _PersonalSortOption { timeDesc, timeAsc, amountDesc, amountAsc }

class _PersonalTransactionsScreenState extends ConsumerState<PersonalTransactionsScreen> {
  String _search = '';
  TransactionType? _filter;
  String? _categoryFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _PersonalSortOption _sortOption = _PersonalSortOption.timeDesc;

  bool get _hasAdvancedFilters =>
      _categoryFilter != null || _dateFrom != null || _dateTo != null || _sortOption != _PersonalSortOption.timeDesc;

  void _showFilterSheet(BuildContext context, List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PersonalFilterBottomSheet(
        categories: categories,
        categoryFilter: _categoryFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        sortOption: _sortOption,
        onApply: (cat, from, to, sort) {
          setState(() { _categoryFilter = cat; _dateFrom = from; _dateTo = to; _sortOption = sort; });
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() { _categoryFilter = null; _dateFrom = null; _dateTo = null; _sortOption = _PersonalSortOption.timeDesc; });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(personalTransactionsProvider(widget.monthKey));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Transactions • ${_formatMonth(widget.monthKey)}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddPersonalTransactionSheet(context),
        child: const Icon(Icons.add),
      ),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final msg = e.toString();
          final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s]+').firstMatch(msg);
          if (urlMatch != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: urlMatch.group(0)!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Index URL copied! Open in browser.')),
                    );
                  },
                  child: Text(
                    'Index required. Tap to copy URL:\n${urlMatch.group(0)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orange, decoration: TextDecoration.underline),
                  ),
                ),
              ),
            );
          }
          return Center(child: Text('Error: $msg'));
        },
        data: (txns) {
          var filtered = txns.where((t) {
            if (_filter != null && t.type != _filter) return false;
            if (_search.isNotEmpty && !t.title.toLowerCase().contains(_search.toLowerCase())) return false;
            if (_categoryFilter != null && t.category != _categoryFilter) return false;
            if (_dateFrom != null && t.date.isBefore(_dateFrom!)) return false;
            if (_dateTo != null && t.date.isAfter(_dateTo!.add(const Duration(days: 1)))) return false;
            return true;
          }).toList();
          switch (_sortOption) {
            case _PersonalSortOption.timeDesc: filtered.sort((a, b) => b.date.compareTo(a.date));
            case _PersonalSortOption.timeAsc: filtered.sort((a, b) => a.date.compareTo(b.date));
            case _PersonalSortOption.amountDesc: filtered.sort((a, b) => b.amount.compareTo(a.amount));
            case _PersonalSortOption.amountAsc: filtered.sort((a, b) => a.amount.compareTo(b.amount));
          }
          final categories = txns.map((t) => t.category).toSet().toList()..sort();

          return Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips + filter icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _FilterChip(label: 'All', icon: Icons.list, selected: _filter == null, onTap: () => setState(() => _filter = null))),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Expenses', icon: Icons.arrow_upward, selected: _filter == TransactionType.expense, onTap: () => setState(() => _filter = TransactionType.expense))),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Income', icon: Icons.arrow_downward, selected: _filter == TransactionType.income, onTap: () => setState(() => _filter = TransactionType.income))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showFilterSheet(context, categories),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasAdvancedFilters
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune,
                          size: 18,
                          color: _hasAdvancedFilters ? Colors.white : Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Transaction count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('${filtered.length} transactions', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Day-wise grouped list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            const Text('No transactions found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _DayWiseList(transactions: filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatMonth(String key) {
    final parts = key.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMM yyyy').format(dt);
  }
}

class _DayWiseList extends StatelessWidget {
  final List<PersonalTransactionModel> transactions;
  const _DayWiseList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Group by date
    final grouped = <String, List<PersonalTransactionModel>>{};
    for (final t in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: sortedKeys.length,
      itemBuilder: (context, i) {
        final dateKey = sortedKeys[i];
        final dayTxns = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);
        final dayExpense = dayTxns.where((t) => t.isExpense).fold<double>(0, (s, t) => s + t.amount);
        final dayIncome = dayTxns.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  Text(
                    isToday ? 'Today' : DateFormat('EEE, dd MMM').format(date),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  const Spacer(),
                  if (dayExpense > 0)
                    Text('-₹${dayExpense.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                  if (dayExpense > 0 && dayIncome > 0)
                    const SizedBox(width: 8),
                  if (dayIncome > 0)
                    Text('+₹${dayIncome.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                ],
              ),
            ),
            ...dayTxns.map((txn) => _TxnCard(
              txn: txn,
              onTap: () => showPersonalTransactionDetail(context, txn),
            )),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : (isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Theme.of(context).colorScheme.onPrimary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnCard extends StatelessWidget {
  final PersonalTransactionModel txn;
  final VoidCallback onTap;
  const _TxnCard({required this.txn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.isIncome;
    final color = isIncome ? Colors.green : Colors.red;
    final sign = isIncome ? '+' : '-';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
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
              backgroundColor: color.withOpacity(0.1),
              child: Icon(isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${txn.category} • ${DateFormat('dd MMM').format(txn.date)}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Text('$sign₹${txn.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PersonalFilterBottomSheet extends StatefulWidget {
  final List<String> categories;
  final String? categoryFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final _PersonalSortOption sortOption;
  final void Function(String?, DateTime?, DateTime?, _PersonalSortOption) onApply;
  final VoidCallback onClear;

  const _PersonalFilterBottomSheet({
    required this.categories,
    required this.categoryFilter,
    required this.dateFrom,
    required this.dateTo,
    required this.sortOption,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_PersonalFilterBottomSheet> createState() => _PersonalFilterBottomSheetState();
}

class _PersonalFilterBottomSheetState extends State<_PersonalFilterBottomSheet> {
  late String? _category;
  late DateTime? _from;
  late DateTime? _to;
  late _PersonalSortOption _sort;

  @override
  void initState() {
    super.initState();
    _category = widget.categoryFilter;
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
      child: SingleChildScrollView(
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
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 4,
              children: [
                ChoiceChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                ...widget.categories.map((c) => ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c))),
              ],
            ),
            const SizedBox(height: 14),
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
                ChoiceChip(label: const Text('Newest'), selected: _sort == _PersonalSortOption.timeDesc, onSelected: (_) => setState(() => _sort = _PersonalSortOption.timeDesc)),
                ChoiceChip(label: const Text('Oldest'), selected: _sort == _PersonalSortOption.timeAsc, onSelected: (_) => setState(() => _sort = _PersonalSortOption.timeAsc)),
                ChoiceChip(label: const Text('Amount ↑'), selected: _sort == _PersonalSortOption.amountAsc, onSelected: (_) => setState(() => _sort = _PersonalSortOption.amountAsc)),
                ChoiceChip(label: const Text('Amount ↓'), selected: _sort == _PersonalSortOption.amountDesc, onSelected: (_) => setState(() => _sort = _PersonalSortOption.amountDesc)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onApply(_category, _from, _to, _sort),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
