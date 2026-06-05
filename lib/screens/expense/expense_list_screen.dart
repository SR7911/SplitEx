import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/config/constants.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/models/activity_model.dart';
import 'package:split_ex/providers/activity_provider.dart';

enum SortOption { timeDesc, timeAsc, amountDesc, amountAsc }

class ExpenseListScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ExpenseListScreen({super.key, required this.roomId});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  late DateTime _selectedMonth;

  // Filter state
  String? _filterUser;
  String? _filterCategory;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  // Sort state
  SortOption _sortOption = SortOption.timeDesc;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _clearFilters();
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() {
        _selectedMonth = next;
        _clearFilters();
      });
    }
  }

  void _clearFilters() {
    _filterUser = null;
    _filterCategory = null;
    _filterDateFrom = null;
    _filterDateTo = null;
  }

  bool get _hasActiveFilters =>
      _filterUser != null ||
      _filterCategory != null ||
      _filterDateFrom != null ||
      _filterDateTo != null;

  List<ExpenseModel> _applyFiltersAndSort(List<ExpenseModel> expenses) {
    var filtered = expenses.where((e) {
      if (_filterUser != null && e.paidBy != _filterUser) return false;
      if (_filterCategory != null && e.category != _filterCategory) return false;
      if (_filterDateFrom != null && e.date.isBefore(_filterDateFrom!)) return false;
      if (_filterDateTo != null && e.date.isAfter(_filterDateTo!.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    switch (_sortOption) {
      case SortOption.timeDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
      case SortOption.timeAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
      case SortOption.amountDesc:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
      case SortOption.amountAsc:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return filtered;
  }

  bool _filterExpanded = false;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(monthExpensesProvider(
      MonthRoomKey(roomId: widget.roomId, month: _monthKey),
    ));
    final userId = ref.read(currentUserIdProvider);
    final room = ref.watch(currentRoomProvider);
    final isAdmin = room?.isAdmin(userId) ?? false;

    final members = room?.memberIds ?? [];
    final membersAsync = ref.watch(roomMembersProvider(members));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) {
        nameMap[m.uid] = m.name;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'activity':
                  context.push('/room/${widget.roomId}/activity');
                case 'analytics':
                  context.push('/room/${widget.roomId}/analytics');
                case 'dashboard':
                  context.push('/room/${widget.roomId}/dashboard');
                case 'settings':
                  context.push('/room/${widget.roomId}/settings');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'dashboard', child: Text('Dashboard')),
              PopupMenuItem(value: 'analytics', child: Text('Analytics')),
              PopupMenuItem(value: 'activity', child: Text('Activity Log')),
              PopupMenuItem(value: 'settings', child: Text('Room Settings')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthSelector(
            month: _selectedMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          _FilterSortPanel(
            expanded: _filterExpanded,
            onToggle: () => setState(() => _filterExpanded = !_filterExpanded),
            nameMap: nameMap,
            selectedMonth: _selectedMonth,
            filterUser: _filterUser,
            filterCategory: _filterCategory,
            filterDateFrom: _filterDateFrom,
            filterDateTo: _filterDateTo,
            sortOption: _sortOption,
            hasActiveFilters: _hasActiveFilters,
            onUserChanged: (v) => setState(() => _filterUser = v),
            onCategoryChanged: (v) => setState(() => _filterCategory = v),
            onDateFromChanged: (v) => setState(() => _filterDateFrom = v),
            onDateToChanged: (v) => setState(() => _filterDateTo = v),
            onSortChanged: (v) => setState(() => _sortOption = v),
            onClear: () => setState(() => _clearFilters()),
          ),
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                final filtered = _applyFiltersAndSort(expenses);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_hasActiveFilters
                            ? 'No expenses match filters'
                            : 'No expenses this month'),
                      ],
                    ),
                  );
                }
                final total = filtered.fold<double>(0, (s, e) => s + e.amount);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TotalCard(total: total, count: filtered.length),
                    const SizedBox(height: 12),
                    ...filtered.map((expense) => _ExpenseTile(
                          expense: expense,
                          isAdmin: isAdmin,
                          userId: userId,
                          roomId: widget.roomId,
                          nameMap: nameMap,
                        )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/room/${widget.roomId}/add-expense'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- Filter & Sort Panel (inline expandable) ---

class _FilterSortPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final Map<String, String> nameMap;
  final DateTime selectedMonth;
  final String? filterUser;
  final String? filterCategory;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final SortOption sortOption;
  final bool hasActiveFilters;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final ValueChanged<SortOption> onSortChanged;
  final VoidCallback onClear;

  const _FilterSortPanel({
    required this.expanded,
    required this.onToggle,
    required this.nameMap,
    required this.selectedMonth,
    required this.filterUser,
    required this.filterCategory,
    required this.filterDateFrom,
    required this.filterDateTo,
    required this.sortOption,
    required this.hasActiveFilters,
    required this.onUserChanged,
    required this.onCategoryChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? filterDateFrom : filterDateTo) ?? firstDay,
      firstDate: firstDay,
      lastDate: lastDay,
    );
    if (picked != null) {
      if (isFrom) onDateFromChanged(picked);
      else onDateToChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: hasActiveFilters
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).iconTheme.color,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Filter & Sort',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: hasActiveFilters
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                  ),
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ON',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (hasActiveFilters)
                    GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: Theme.of(context).dividerColor),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildContent(context),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paid by
          Text('Paid by', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filterUser == null,
                  onSelected: (_) => onUserChanged(null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ...nameMap.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: filterUser == e.key,
                        onSelected: (_) => onUserChanged(e.key),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category
          Text('Category', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filterCategory == null,
                  onSelected: (_) => onCategoryChanged(null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ...AppConstants.expenseCategories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: filterCategory == c,
                        onSelected: (_) => onCategoryChanged(c),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Date range
          Text('Date range', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(context, true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    filterDateFrom != null
                        ? DateFormat('dd MMM').format(filterDateFrom!)
                        : 'From',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('—'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    filterDateTo != null
                        ? DateFormat('dd MMM').format(filterDateTo!)
                        : 'To',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (filterDateFrom != null || filterDateTo != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    onDateFromChanged(null);
                    onDateToChanged(null);
                  },
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Sort
          Text('Sort by', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Newest'),
                  selected: sortOption == SortOption.timeDesc,
                  onSelected: (_) => onSortChanged(SortOption.timeDesc),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Oldest'),
                  selected: sortOption == SortOption.timeAsc,
                  onSelected: (_) => onSortChanged(SortOption.timeAsc),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Amount ↑'),
                  selected: sortOption == SortOption.amountAsc,
                  onSelected: (_) => onSortChanged(SortOption.amountAsc),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Amount ↓'),
                  selected: sortOption == SortOption.amountDesc,
                  onSelected: (_) => onSortChanged(SortOption.amountDesc),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Month Selector ---

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthSelector({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : onNext,
          ),
        ],
      ),
    );
  }
}

// --- Total Card ---

class _TotalCard extends StatelessWidget {
  final double total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Spent', style: Theme.of(context).textTheme.bodySmall),
                Text('₹${total.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
            Text('$count expenses', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// --- Expense Tile ---

const _memberColors = <Color>[
  Color(0xFF7C4DFF),
  Color(0xFF00BCD4),
  Color(0xFFFF7043),
  Color(0xFF66BB6A),
  Color(0xFFFFCA28),
  Color(0xFFEC407A),
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFAB47BC),
  Color(0xFFEF5350),
];

class _ExpenseTile extends ConsumerWidget {
  final ExpenseModel expense;
  final bool isAdmin;
  final String userId;
  final String roomId;
  final Map<String, String> nameMap;

  const _ExpenseTile({
    required this.expense,
    required this.isAdmin,
    required this.userId,
    required this.roomId,
    required this.nameMap,
  });

  Color _colorForMember(String memberId) {
    final members = nameMap.keys.toList()..sort();
    final index = members.indexOf(memberId);
    return _memberColors[index % _memberColors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = expense.createdBy == userId || isAdmin;
    final icon =
        AppConstants.categoryIcons[expense.category] ?? Icons.receipt_long;
    final paidByName = expense.paidBy == userId
        ? 'You'
        : (nameMap[expense.paidBy] ?? expense.paidBy);
    final memberColor = _colorForMember(expense.paidBy);

    final tile = Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: memberColor.withOpacity(0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: memberColor, width: 4)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: memberColor.withOpacity(0.15),
            child: Icon(icon, size: 20, color: memberColor),
          ),
          title: Text(expense.title),
          subtitle: Text(
            '${expense.category} • ${DateFormat('dd MMM').format(expense.date)} • paid by $paidByName',
          ),
          trailing: Text(
            '₹${expense.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: memberColor,
                ),
          ),
          onTap: canEdit
              ? () => context.push('/room/$roomId/edit-expense', extra: expense)
              : null,
        ),
      ),
    );

    if (!isAdmin) return tile;

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Card(
        color: Colors.red,
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text('Delete "${expense.title}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(expenseServiceProvider).deleteExpense(roomId, expense.id);
        ref.read(activityServiceProvider).log(
              roomId: roomId,
              type: ActivityType.expenseDeleted,
              performedBy: userId,
              description: 'Deleted "${expense.title}"',
              metadata: {
                'title': expense.title,
                'amount': expense.amount,
                'category': expense.category,
                'paidBy': expense.paidBy,
                'splitAmong': expense.splitAmong,
                'date': DateFormat('dd MMM yyyy').format(expense.date),
              },
            );
      },
      child: tile,
    );
  }
}
