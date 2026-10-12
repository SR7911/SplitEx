import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_debt_sheet.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);

class DebtListScreen extends ConsumerStatefulWidget {
  const DebtListScreen({super.key});

  @override
  ConsumerState<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends ConsumerState<DebtListScreen> {
  late DateTime _selectedMonth;
  final _searchCtrl = TextEditingController();
  String _filterType = 'all'; // all, lent, borrowed
  String _filterStatus = 'all'; // all, active, settled
  String _filterAmount = 'all'; // all, low, medium, high
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() => setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      });

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  List<PersonalTransactionModel> _applyFilters(List<PersonalTransactionModel> debts) {
    var result = debts;

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((t) =>
          (t.personName ?? '').toLowerCase().contains(query) ||
          t.title.toLowerCase().contains(query)).toList();
    }

    if (_filterType == 'lent') result = result.where((t) => t.debtType == DebtType.lent).toList();
    if (_filterType == 'borrowed') result = result.where((t) => t.debtType == DebtType.borrowed).toList();

    if (_filterStatus == 'active') result = result.where((t) => !t.isSettled).toList();
    if (_filterStatus == 'settled') result = result.where((t) => t.isSettled).toList();

    if (_filterAmount == 'low') result = result.where((t) => t.amount < 500).toList();
    if (_filterAmount == 'medium') result = result.where((t) => t.amount >= 500 && t.amount < 5000).toList();
    if (_filterAmount == 'high') result = result.where((t) => t.amount >= 5000).toList();

    return result;
  }

  bool get _hasActiveFilters =>
      _filterType != 'all' || _filterStatus != 'all' || _filterAmount != 'all' || _searchCtrl.text.isNotEmpty;

  void _resetFilters() => setState(() {
        _filterType = 'all';
        _filterStatus = 'all';
        _filterAmount = 'all';
        _searchCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    final monthDebts = ref.watch(personalDebtsByMonthProvider(_monthKey));
    final filtered = _applyFilters(monthDebts);

    final lent = filtered.where((t) => t.debtType == DebtType.lent).toList();
    final borrowed = filtered.where((t) => t.debtType == DebtType.borrowed).toList();

    final totalLent = monthDebts.where((t) => t.debtType == DebtType.lent && !t.isSettled).fold<double>(0, (s, t) => s + t.remainingAmount);
    final totalBorrowed = monthDebts.where((t) => t.debtType == DebtType.borrowed && !t.isSettled).fold<double>(0, (s, t) => s + t.remainingAmount);
    final net = totalLent - totalBorrowed;

    return Scaffold(
      appBar: AppHeader(
        showBack: true,
        title: 'Monthly Debts',
        showNotification: false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_showSearch ? Icons.search_off : Icons.search, size: 20),
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchCtrl.clear();
              }),
            ),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.filter_list_rounded, size: 20),
                  if (_hasActiveFilters)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: _kAmber, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showFilterSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => showAddDebtSheet(context, initialMonth: _monthKey),
            ),
          ],
        ),
      ),
      body: GradientBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // Month selector
            AppMonthSelector(
              selectedMonth: _selectedMonth,
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),
            const SizedBox(height: 12),

            // Month hero card
            _MonthHeroCard(totalLent: totalLent, totalBorrowed: totalBorrowed, net: net, count: monthDebts.length),
            const SizedBox(height: 16),

            // Search bar
            if (_showSearch) ...[
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by person or description...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchCtrl.clear()))
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Active filter chips
            if (_hasActiveFilters) ...[
              _ActiveFilterChips(
                filterType: _filterType,
                filterStatus: _filterStatus,
                filterAmount: _filterAmount,
                query: _searchCtrl.text,
                onReset: _resetFilters,
              ),
              const SizedBox(height: 12),
            ],

            // Empty state
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: AppEmptyState(
                  icon: Icons.handshake_outlined,
                  title: _hasActiveFilters ? 'No matching debts' : 'No debts this month',
                  subtitle: _hasActiveFilters ? 'Try adjusting your filters' : 'Add a debt to get started',
                  actionLabel: _hasActiveFilters ? 'Clear Filters' : 'Add Debt',
                  onAction: _hasActiveFilters ? _resetFilters : () => showAddDebtSheet(context, initialMonth: _monthKey),
                ),
              )
            else ...[
              // Lent section
              if (lent.isNotEmpty) ...[
                _DebtSectionHeader(title: 'Money You Lent', color: _kGreen, icon: Icons.call_made, count: lent.length),
                const SizedBox(height: 8),
                ...lent.map((t) => _DebtTileWrapper(txn: t)),
                const SizedBox(height: 20),
              ],

              // Borrowed section
              if (borrowed.isNotEmpty) ...[
                _DebtSectionHeader(title: 'Money You Borrowed', color: _kRed, icon: Icons.call_received, count: borrowed.length),
                const SizedBox(height: 8),
                ...borrowed.map((t) => _DebtTileWrapper(txn: t)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        filterType: _filterType,
        filterStatus: _filterStatus,
        filterAmount: _filterAmount,
        onApply: (type, status, amount) => setState(() {
          _filterType = type;
          _filterStatus = status;
          _filterAmount = amount;
        }),
        onReset: _resetFilters,
      ),
    );
  }
}

// ── Month Hero Card ────────────────────────────────────────────────────────

class _MonthHeroCard extends StatelessWidget {
  final double totalLent;
  final double totalBorrowed;
  final double net;
  final int count;
  const _MonthHeroCard({required this.totalLent, required this.totalBorrowed, required this.net, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: appCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _StatCol(label: 'Lent', value: '₹${totalLent.toStringAsFixed(0)}', color: _kGreen)),
          Container(width: 1, height: 40, color: cs.outline.withValues(alpha: 0.15)),
          Expanded(child: _StatCol(label: 'Borrowed', value: '₹${totalBorrowed.toStringAsFixed(0)}', color: _kRed)),
          Container(width: 1, height: 40, color: cs.outline.withValues(alpha: 0.15)),
          Expanded(child: _StatCol(label: 'Net', value: '${net >= 0 ? '+' : ''}₹${net.toStringAsFixed(0)}', color: net >= 0 ? _kGreen : _kRed)),
          Container(width: 1, height: 40, color: cs.outline.withValues(alpha: 0.15)),
          Expanded(child: _StatCol(label: 'Count', value: '$count', color: cs.primary)),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCol({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────

class _DebtSectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final int count;
  const _DebtSectionHeader({required this.title, required this.color, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

// ── Debt Tile Wrapper (reuses existing _DebtTile logic) ───────────────────

class _DebtTileWrapper extends ConsumerWidget {
  final PersonalTransactionModel txn;
  const _DebtTileWrapper({required this.txn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLent = txn.debtType == DebtType.lent;
    final color = isLent ? _kGreen : _kRed;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settled = txn.isSettled;
    final hasPartial = txn.settledAmount > 0 && !settled;

    return Opacity(
      opacity: settled ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: settled ? Colors.grey : (hasPartial ? _kAmber : color), width: 3)),
          boxShadow: [if (!isDark && !settled) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (settled ? Colors.grey : color).withValues(alpha: 0.1),
                child: settled
                    ? const Icon(Icons.check, color: Colors.grey, size: 14)
                    : Text((txn.personName ?? '?')[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(txn.personName ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        if (settled)
                          _Pill(label: 'Settled', color: Colors.grey)
                        else if (hasPartial)
                          _Pill(label: 'Partial', color: _kAmber),
                      ],
                    ),
                    Text(txn.title, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${txn.category} • ${DateFormat('dd MMM').format(txn.date)}', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${txn.remainingAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: settled ? Colors.grey : color),
                  ),
                  if (hasPartial)
                    Text('of ₹${txn.amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Active Filter Chips ────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  final String filterType;
  final String filterStatus;
  final String filterAmount;
  final String query;
  final VoidCallback onReset;
  const _ActiveFilterChips({
    required this.filterType,
    required this.filterStatus,
    required this.filterAmount,
    required this.query,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <String>[];
    if (filterType != 'all') chips.add(filterType == 'lent' ? 'Lent' : 'Borrowed');
    if (filterStatus != 'all') chips.add(filterStatus == 'active' ? 'Active' : 'Settled');
    if (filterAmount != 'all') chips.add('Amount: $filterAmount');
    if (query.isNotEmpty) chips.add('Search: "$query"');

    return Wrap(
      spacing: 8,
      children: [
        ...chips.map((c) => Chip(
          label: Text(c, style: const TextStyle(fontSize: 11)),
          backgroundColor: cs.primary.withValues(alpha: 0.08),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        )),
        ActionChip(
          label: const Text('Clear', style: TextStyle(fontSize: 11)),
          onPressed: onReset,
          backgroundColor: _kRed.withValues(alpha: 0.08),
          side: BorderSide(color: _kRed.withValues(alpha: 0.2)),
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ],
    );
  }
}

// ── Filter Sheet ───────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String filterType;
  final String filterStatus;
  final String filterAmount;
  final void Function(String type, String status, String amount) onApply;
  final VoidCallback onReset;
  const _FilterSheet({
    required this.filterType,
    required this.filterStatus,
    required this.filterAmount,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _type;
  late String _status;
  late String _amount;

  @override
  void initState() {
    super.initState();
    _type = widget.filterType;
    _status = widget.filterStatus;
    _amount = widget.filterAmount;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _FilterGroup(
            label: 'Type',
            options: const {'all': 'All', 'lent': 'Lent', 'borrowed': 'Borrowed'},
            selected: _type,
            onSelect: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 16),
          _FilterGroup(
            label: 'Status',
            options: const {'all': 'All', 'active': 'Active', 'settled': 'Settled'},
            selected: _status,
            onSelect: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 16),
          _FilterGroup(
            label: 'Amount',
            options: const {'all': 'All', 'low': '< ₹500', 'medium': '₹500–5K', 'high': '> ₹5K'},
            selected: _amount,
            onSelect: (v) => setState(() => _amount = v),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onReset();
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onApply(_type, _status, _amount);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String selected;
  final void Function(String) onSelect;
  const _FilterGroup({required this.label, required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.entries.map((e) {
            final isSelected = selected == e.key;
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? cs.primary.withValues(alpha: 0.4) : Colors.transparent),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
