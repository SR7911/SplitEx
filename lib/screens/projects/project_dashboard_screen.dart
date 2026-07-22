import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/projects/add_project_expense_sheet.dart';

class ProjectDashboardScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ProjectDashboardScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectStreamProvider(widget.projectId));
    final uid = ref.watch(currentUserIdProvider);

    return projectAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (project) {
        if (project == null) return const Scaffold(body: Center(child: Text('Project not found')));

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              PopupMenuButton<ProjectStatus>(
                onSelected: (status) async {
                  await ref.read(projectServiceProvider).updateStatus(uid, widget.projectId, status);
                },
                itemBuilder: (_) => ProjectStatus.values
                    .where((s) => s != project.status)
                    .map((s) => PopupMenuItem(value: s, child: Text('Mark as ${s.name}')))
                    .toList(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Overview'), Tab(text: 'Expenses')],
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              indicatorSize: TabBarIndicatorSize.label,
            ),
          ),
          floatingActionButton: project.status == ProjectStatus.completed
              ? null
              : FloatingActionButton(
                  onPressed: () => showAddProjectExpenseSheet(context, projectId: widget.projectId),
                  child: const Icon(Icons.add),
                ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(project: project),
              _ExpensesTab(projectId: widget.projectId, uid: uid),
            ],
          ),
        );
      },
    );
  }
}

// ─── Overview Tab ────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final ProjectModel project;
  const _OverviewTab({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSpent = ref.watch(projectTotalSpentProvider(project.id));
    final remaining = project.estimatedBudget - totalSpent;
    final progress = project.estimatedBudget > 0
        ? (totalSpent / project.estimatedBudget).clamp(0.0, 1.0)
        : 0.0;
    final isOver = totalSpent > project.estimatedBudget;
    final categoryBreakdown = ref.watch(projectCategoryBreakdownProvider(project.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Budget card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Budget Overview', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _BudgetStat(label: 'Budget', value: '₹${project.estimatedBudget.toStringAsFixed(0)}', color: Colors.blue)),
                    Expanded(child: _BudgetStat(label: 'Spent', value: '₹${totalSpent.toStringAsFixed(0)}', color: isOver ? Colors.red : Colors.orange)),
                    Expanded(child: _BudgetStat(label: 'Remaining', value: '₹${remaining.abs().toStringAsFixed(0)}', color: remaining >= 0 ? Colors.green : Colors.red)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(progress * 100).toStringAsFixed(0)}% used', style: const TextStyle(fontSize: 12)),
                    if (isOver) const Text('Over budget!', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: isOver ? Colors.red : progress > 0.8 ? Colors.orange : Colors.green,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Project info
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 12),
                _InfoRow(label: 'Type', value: project.projectType),
                _InfoRow(label: 'Start', value: DateFormat('dd MMM yyyy').format(project.startDate)),
                if (project.targetEndDate != null)
                  _InfoRow(label: 'Target End', value: DateFormat('dd MMM yyyy').format(project.targetEndDate!)),
                if (project.description != null && project.description!.isNotEmpty)
                  _InfoRow(label: 'Description', value: project.description!),
              ],
            ),
          ),
        ),
        if (categoryBreakdown.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('By Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 12),
                  ...categoryBreakdown.entries.map((e) => _CategoryBar(
                        label: e.key,
                        amount: e.value,
                        total: totalSpent,
                      )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BudgetStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final double amount;
  final double total;
  const _CategoryBar({required this.label, required this.amount, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text('₹${amount.toStringAsFixed(0)} (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Expenses Tab ────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  final String projectId;
  final String uid;
  const _ExpensesTab({required this.projectId, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(projectExpensesProvider(projectId));

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No expenses yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e = expenses[i];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${e.category}${e.vendor != null ? ' • ${e.vendor}' : ''} • ${DateFormat('dd MMM yyyy').format(e.date)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(e.paymentMethod.name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Expense?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(projectExpenseServiceProvider).deleteExpense(uid, projectId, e.id);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
