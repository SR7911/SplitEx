import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/screens/projects/add_project_expense_sheet.dart';
import 'package:split_ex/screens/projects/project_reports_screen.dart';

class ProjectDashboardScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDashboardScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectStreamProvider(projectId));
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
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded),
                tooltip: 'Reports',
                onPressed: () => showProjectReportsSheet(context, projectId),
              ),
              PopupMenuButton<ProjectStatus>(
                onSelected: (status) =>
                    ref.read(projectServiceProvider).updateStatus(uid, projectId, status),
                itemBuilder: (_) => ProjectStatus.values
                    .where((s) => s != project.status)
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text('Mark as ${s.name[0].toUpperCase()}${s.name.substring(1)}'),
                        ))
                    .toList(),
              ),
            ],
          ),
          floatingActionButton: project.status == ProjectStatus.completed
              ? null
              : FloatingActionButton(
                  onPressed: () => showAddProjectExpenseSheet(context, projectId: projectId),
                  child: const Icon(Icons.add),
                ),
          body: _DashboardBody(project: project),
        );
      },
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final ProjectModel project;
  const _DashboardBody({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSpent = ref.watch(projectTotalSpentProvider(project.id));
    final remaining = project.estimatedBudget - totalSpent;
    final progress = project.estimatedBudget > 0
        ? (totalSpent / project.estimatedBudget).clamp(0.0, 1.0)
        : 0.0;
    final isOver = totalSpent > project.estimatedBudget;
    final debtSummary = ref.watch(projectDebtSummaryProvider(project.id));
    final personDebts = ref.watch(projectPersonDebtsProvider(project.id));
    final categoryBreakdown = ref.watch(projectCategoryBreakdownProvider(project.id));
    final paymentBreakdown = ref.watch(projectPaymentBreakdownProvider(project.id));
    final expensesAsync = ref.watch(projectExpensesProvider(project.id));
    final expenses = expensesAsync.valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _BudgetCard(
          project: project,
          totalSpent: totalSpent,
          remaining: remaining,
          progress: progress,
          isOver: isOver,
        ),
        const SizedBox(height: 12),
        _QuickActions(projectId: project.id, isCompleted: project.status == ProjectStatus.completed),
        const SizedBox(height: 12),
        if (expenses.isNotEmpty) ...[
          _InsightsCard(
            expenses: expenses,
            totalSpent: totalSpent,
            categoryBreakdown: categoryBreakdown,
            paymentBreakdown: paymentBreakdown,
          ),
          const SizedBox(height: 12),
        ],
        if (debtSummary.lent > 0 || debtSummary.borrowed > 0) ...[
          _DebtCard(debtSummary: debtSummary, personDebts: personDebts),
          const SizedBox(height: 12),
        ],
        _DetailsCard(project: project),
        const SizedBox(height: 12),
        _RecentExpensesCard(projectId: project.id, expenses: expenses.take(5).toList()),
      ],
    );
  }
}

// ─── Budget Card ──────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final ProjectModel project;
  final double totalSpent;
  final double remaining;
  final double progress;
  final bool isOver;

  const _BudgetCard({
    required this.project,
    required this.totalSpent,
    required this.remaining,
    required this.progress,
    required this.isOver,
  });

  static IconData _typeIcon(String type) => switch (type) {
        'House Construction' => Icons.home_work_outlined,
        'Renovation' => Icons.construction_rounded,
        'Wedding' => Icons.favorite_border_rounded,
        'Business Setup' => Icons.business_center_outlined,
        'Office Setup' => Icons.corporate_fare_rounded,
        'Shop Renovation' => Icons.storefront_outlined,
        'Event' => Icons.celebration_outlined,
        _ => Icons.folder_outlined,
      };

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gaugeColor = isOver
        ? const Color(0xFFEF4444)
        : progress > 0.8
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    final (statusColor, statusIcon, statusLabel) = switch (project.status) {
      ProjectStatus.active => (const Color(0xFF10B981), Icons.play_circle_outline, 'Active'),
      ProjectStatus.completed => (const Color(0xFF3B82F6), Icons.check_circle_outline, 'Completed'),
      ProjectStatus.paused => (const Color(0xFFF59E0B), Icons.pause_circle_outline, 'Paused'),
    };

    final daysLeft = project.targetEndDate?.difference(DateTime.now()).inDays;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(project.projectType), color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        project.projectType,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                _StatusPill(color: statusColor, icon: statusIcon, label: statusLabel),
              ],
            ),

            const SizedBox(height: 20),

            // Progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Budget used', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55))),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gaugeColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: cs.onSurface.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(gaugeColor),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Budget stats
            Row(
              children: [
                _BudgetStat(label: 'Budget', value: _fmt(project.estimatedBudget), color: cs.onSurface.withOpacity(0.7)),
                _BudgetStat(label: 'Spent', value: _fmt(totalSpent), color: gaugeColor),
                _BudgetStat(
                  label: isOver ? 'Over by' : 'Remaining',
                  value: _fmt(remaining.abs()),
                  color: isOver ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ],
            ),

            // Meta pills
            if (project.targetEndDate != null || isOver) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('dd MMM yy').format(project.startDate),
                  ),
                  if (daysLeft != null)
                    _MetaPill(
                      icon: daysLeft < 0 ? Icons.flag_rounded : Icons.hourglass_bottom_rounded,
                      label: daysLeft < 0 ? 'Ended ${-daysLeft}d ago' : '$daysLeft days left',
                      highlight: daysLeft >= 0 && daysLeft <= 7,
                    ),
                  if (isOver)
                    _MetaPill(
                      icon: Icons.warning_amber_rounded,
                      label: 'Over budget',
                      highlight: true,
                      highlightColor: const Color(0xFFEF4444),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _StatusPill({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final Color? highlightColor;
  const _MetaPill({required this.icon, required this.label, this.highlight = false, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    final color = highlight ? (highlightColor ?? const Color(0xFFF59E0B)) : base.withOpacity(0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  final String projectId;
  final bool isCompleted;
  const _QuickActions({required this.projectId, required this.isCompleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 5),
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        action(
          Icons.add_circle_outline,
          'Add Expense',
          isCompleted ? cs.onSurface.withOpacity(0.3) : cs.primary,
          isCompleted ? () {} : () => showAddProjectExpenseSheet(context, projectId: projectId),
        ),
        const SizedBox(width: 10),
        action(Icons.bar_chart_rounded, 'Reports', Colors.purple,
            () => showProjectReportsSheet(context, projectId)),
        const SizedBox(width: 10),
        action(Icons.receipt_long_outlined, 'All Expenses', Colors.teal,
            () => context.push('/projects/$projectId/expenses')),
      ],
    );
  }
}

// ─── Insights Card ───────────────────────────────────────────────────────────

class _InsightsCard extends StatelessWidget {
  final List<ProjectExpenseModel> expenses;
  final double totalSpent;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> paymentBreakdown;
  const _InsightsCard({
    required this.expenses,
    required this.totalSpent,
    required this.categoryBreakdown,
    required this.paymentBreakdown,
  });

  static const _pmIcons = {
    'cash': Icons.payments_outlined,
    'upi': Icons.phone_android_rounded,
    'card': Icons.credit_card_rounded,
    'bankTransfer': Icons.account_balance_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avg = totalSpent / expenses.length;
    final topCat = categoryBreakdown.entries.isEmpty
        ? null
        : categoryBreakdown.entries.reduce((a, b) => a.value > b.value ? a : b);
    final topPct = topCat != null && totalSpent > 0
        ? (topCat.value / totalSpent * 100).toStringAsFixed(0)
        : '0';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text('Spending Insights',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 14),
            // Avg + top category
            Row(
              children: [
                Expanded(
                  child: _InsightTile(
                    icon: Icons.calculate_outlined,
                    label: 'Avg per expense',
                    value: '₹${_fmtNum(avg)}',
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InsightTile(
                    icon: Icons.category_outlined,
                    label: 'Top category',
                    value: topCat != null ? '${topCat.key} ($topPct%)' : '—',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            if (paymentBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Payment Methods',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.5))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: paymentBreakdown.entries.map((e) {
                  final pct = totalSpent > 0 ? (e.value / totalSpent * 100).toStringAsFixed(0) : '0';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_pmIcons[e.key] ?? Icons.payment_outlined, size: 12, color: cs.primary),
                        const SizedBox(width: 5),
                        Text(
                          '${_pmLabel(e.key)} · $pct%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.primary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _pmLabel(String key) => switch (key) {
        'cash' => 'Cash',
        'upi' => 'UPI',
        'card' => 'Card',
        'bankTransfer' => 'Bank',
        _ => key,
      };
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InsightTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Debt Card ────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final ({double lent, double borrowed}) debtSummary;
  final Map<String, ({double lent, double borrowed})> personDebts;
  const _DebtCard({required this.debtSummary, required this.personDebts});

  @override
  Widget build(BuildContext context) {
    final net = debtSummary.lent - debtSummary.borrowed;
    final netColor = net >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined, size: 16, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text('Debt Summary',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _DebtStat(label: 'You Lent', value: '₹${debtSummary.lent.toStringAsFixed(0)}', color: const Color(0xFF10B981)),
                _DebtStat(label: 'You Borrowed', value: '₹${debtSummary.borrowed.toStringAsFixed(0)}', color: const Color(0xFFEF4444)),
                _DebtStat(
                  label: net >= 0 ? 'Net Receivable' : 'Net Payable',
                  value: '₹${net.abs().toStringAsFixed(0)}',
                  color: netColor,
                ),
              ],
            ),
            if (personDebts.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Unsettled by Person',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.5))),
              const SizedBox(height: 8),
              ...personDebts.entries.map((entry) {
                final name = entry.key;
                final d = entry.value;
                final personNet = d.lent - d.borrowed;
                final personColor = personNet >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: personColor.withOpacity(0.12),
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: personColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                      ),
                      Text(
                        personNet >= 0
                            ? '₹${personNet.toStringAsFixed(0)} to receive'
                            : '₹${personNet.abs().toStringAsFixed(0)} to pay',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: personColor),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebtStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DebtStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Details Card ─────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final ProjectModel project;
  const _DetailsCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text('Project Details',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Type', value: project.projectType),
            _InfoRow(label: 'Status', value: project.status.name[0].toUpperCase() + project.status.name.substring(1)),
            _InfoRow(label: 'Start Date', value: DateFormat('dd MMM yyyy').format(project.startDate)),
            if (project.targetEndDate != null)
              _InfoRow(label: 'Target End', value: DateFormat('dd MMM yyyy').format(project.targetEndDate!)),
            if (project.description?.isNotEmpty == true)
              _InfoRow(label: 'Description', value: project.description!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.55))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Expenses Card ─────────────────────────────────────────────────────

class _RecentExpensesCard extends StatelessWidget {
  final String projectId;
  final List<ProjectExpenseModel> expenses;
  const _RecentExpensesCard({required this.projectId, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text('Recent Expenses',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/projects/$projectId/expenses'),
                  child: Text('View All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 36, color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      Text('No expenses yet',
                          style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
              )
            else
              ...expenses.map((e) => _ExpenseTile(expense: e)),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final ProjectExpenseModel expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLent = expense.debtType == ProjectDebtType.lent;
    final debtColor = isLent ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: (expense.hasDebt ? debtColor : cs.primary).withOpacity(0.1),
            child: Icon(
              expense.hasDebt
                  ? (isLent ? Icons.call_made_rounded : Icons.call_received_rounded)
                  : Icons.receipt_long_rounded,
              size: 16,
              color: expense.hasDebt ? debtColor : cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${expense.category} · ${DateFormat('dd MMM').format(expense.date)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${expense.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (expense.hasDebt)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (expense.isSettled ? Colors.grey : debtColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expense.isSettled ? 'Settled' : (isLent ? 'Lent' : 'Borrowed'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: expense.isSettled ? Colors.grey : debtColor,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
