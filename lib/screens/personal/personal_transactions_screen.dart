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

class _PersonalTransactionsScreenState extends ConsumerState<PersonalTransactionsScreen> {
  String _search = '';
  TransactionType? _filter;

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
            return true;
          }).toList();

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

              // Filter chips — full width, evenly spaced
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _FilterChip(label: 'All', icon: Icons.list, selected: _filter == null, onTap: () => setState(() => _filter = null))),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Expenses', icon: Icons.arrow_upward, selected: _filter == TransactionType.expense, onTap: () => setState(() => _filter = TransactionType.expense))),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Income', icon: Icons.arrow_downward, selected: _filter == TransactionType.income, onTap: () => setState(() => _filter = TransactionType.income))),
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
