import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

const _kGreen  = Color(0xFF22C55E);
const _kBlue   = Color(0xFF3B82F6);
const _kAmber  = Color(0xFFF59E0B);

const _projectTypes = [
  'House Construction', 'Renovation', 'Wedding', 'Business Setup',
  'Office Setup', 'Shop Renovation', 'Event', 'Other',
];

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(userProjectsProvider);

    return Stack(
      children: [
        projectsAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: 5,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: i == 0
                  ? AppLoadingShimmer.block(height: 200)
                  : AppLoadingShimmer.block(height: 88),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (projects) {
            if (projects.isEmpty) return const _EmptyProjectsState();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _ProjectsHeader(),
                const SizedBox(height: 20),
                _ProjectsHeroCard(projects: projects),
                const SizedBox(height: 16),
                _ProjectsMiniStatRow(projects: projects),
                const SizedBox(height: 20),
                _ProjectsQuickActions(),
                const SizedBox(height: 20),
                const AppSectionHeader(title: 'Your Projects', actionLabel: null, onAction: null),
                const SizedBox(height: 14),
                ...projects.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key == projects.length - 1 ? 0 : 10),
                  child: _ProjectCard(project: e.value),
                )),
              ],
            );
          },
        ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            onPressed: () => context.push('/projects/create'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// -- _ProjectsHeader -------------------------------------------------------

class _ProjectsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Track budgets & expenses per project',
          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

// -- _ProjectsHeroCard ------------------------------------------------------

class _ProjectsHeroCard extends ConsumerWidget {
  final List<ProjectModel> projects;
  const _ProjectsHeroCard({required this.projects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final activeCount  = projects.where((p) => p.status == ProjectStatus.active).length;
    double totalBudget = 0;
    double totalSpent  = 0;
    for (final p in projects) {
      totalBudget += p.estimatedBudget;
      totalSpent  += ref.watch(projectTotalSpentProvider(p.id));
    }
    final isOver        = totalSpent > totalBudget;
    final progress      = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final statusLabel   = isOver ? 'Over Budget' : progress > 0.8 ? 'Caution' : 'On Track';
    final gradientColors = isOver
        ? (isDark ? [const Color(0xFF7F1D1D), const Color(0xFF831843)] : [const Color(0xFFDC2626), const Color(0xFFDB2777)])
        : progress > 0.8
            ? (isDark ? [const Color(0xFF78350F), const Color(0xFF7C2D12)] : [const Color(0xFFD97706), const Color(0xFFEA580C)])
            : (isDark ? [const Color(0xFF064E3B), const Color(0xFF065F46)] : [const Color(0xFF059669), const Color(0xFF0D9488)]);

    final onCard      = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.85);
    final spendRatio  = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: gradientColors.first.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(top: -40, right: -40, child: IgnorePointer(child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06))))),
            Positioned(bottom: -30, left: -30, child: IgnorePointer(child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))))),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.construction_rounded, size: 12, color: onCard),
                          const SizedBox(width: 5),
                          Text('Project Expenses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onCard)),
                        ]),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: onCard)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Total Spent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onCardMuted, letterSpacing: 0.3)),
                  const SizedBox(height: 6),
                  Text(
                    '₹${_compact(totalSpent)}',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1.5, height: 1.1),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AppHeroChip(icon: Icons.folder_open_rounded,           label: 'Active',  value: '$activeCount/${projects.length}', onCard: onCard, onCardMuted: onCardMuted),
                      const SizedBox(width: 10),
                      AppHeroChip(icon: Icons.account_balance_wallet_rounded, label: 'Budget',  value: '₹${_compact(totalBudget)}',       onCard: onCard, onCardMuted: onCardMuted),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isOver ? Icons.warning_amber_rounded : Icons.pie_chart_rounded, size: 16, color: onCard),
                          const SizedBox(height: 2),
                          Text('${(spendRatio * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard)),
                          Text('used', style: TextStyle(fontSize: 9, color: onCardMuted)),
                        ]),
                      ),
                    ],
                  ),
                  if (totalBudget > 0) ...[
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${(spendRatio * 100).toInt()}% of budget used', style: TextStyle(fontSize: 10, color: onCardMuted)),
                        Text(
                          isOver ? '₹${_compact(totalSpent - totalBudget)} over' : '₹${_compact(totalBudget - totalSpent)} left',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: onCard),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: spendRatio,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.9)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// _HeroChip replaced by AppHeroChip from design_system

// -- _ProjectsMiniStatRow --------------------------------------------------

class _ProjectsMiniStatRow extends ConsumerWidget {
  final List<ProjectModel> projects;
  const _ProjectsMiniStatRow({required this.projects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount    = projects.where((p) => p.status == ProjectStatus.active).length;
    final completedCount = projects.where((p) => p.status == ProjectStatus.completed).length;
    double totalBudget   = projects.fold(0.0, (s, p) => s + p.estimatedBudget);

    return Row(
      children: [
        Expanded(child: AppMiniStatCard(label: 'Active',    value: '$activeCount',           icon: Icons.construction_rounded,          color: _kGreen)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Completed', value: '$completedCount',         icon: Icons.check_circle_outline_rounded,  color: _kBlue)),
        const SizedBox(width: 10),
        Expanded(child: AppMiniStatCard(label: 'Budget',    value: '₹${_compact(totalBudget)}', icon: Icons.account_balance_wallet_rounded, color: _kAmber)),
      ],
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// -- _ProjectsQuickActions -------------------------------------------------

class _ProjectsQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = _kGreen;
    return GestureDetector(
      onTap: () => context.push('/projects/create'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20, color: color),
            const SizedBox(width: 8),
            Text('New Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// _QuickAction replaced by AppQuickActionTile from design_system

// -- _ProjectCard ----------------------------------------------------------

class _ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  const _ProjectCard({required this.project});

  static const _typeIcons = <String, IconData>{
    'House Construction': Icons.home_work_rounded,
    'Renovation': Icons.handyman_rounded,
    'Wedding': Icons.favorite_rounded,
    'Business Setup': Icons.business_center_rounded,
    'Office Setup': Icons.corporate_fare_rounded,
    'Shop Renovation': Icons.storefront_rounded,
    'Event': Icons.celebration_rounded,
    'Other': Icons.construction_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSpent = ref.watch(projectTotalSpentProvider(project.id));
    final budget = project.estimatedBudget;
    final progress = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > budget;
    final uid = ref.read(currentUserIdProvider);

    final statusColor = switch (project.status) {
      ProjectStatus.active   => const Color(0xFF22C55E),
      ProjectStatus.completed => const Color(0xFF3B82F6),
      ProjectStatus.paused   => const Color(0xFFF59E0B),
    };
    final progressColor = isOver
        ? const Color(0xFFEF4444)
        : progress > 0.8
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);
    final typeIcon = _typeIcons[project.projectType] ?? Icons.construction_rounded;

    return GestureDetector(
      onTap: () => context.push('/projects/${project.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: appCardDecoration(context, accentColor: statusColor),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(AppRadius.xl),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(typeIcon, size: 20, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface)),
                            const SizedBox(height: 2),
                            Text(project.projectType, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          project.status.name[0].toUpperCase() + project.status.name.substring(1),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (v) {
                          if (v == 'edit') _showEditSheet(context, ref, uid, project);
                          if (v == 'delete') _confirmDelete(context, ref, uid);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 10), Text('Edit', style: TextStyle(fontSize: 13))])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13))])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${_compact(totalSpent)} spent',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: progressColor),
                                ),
                                Text(
                                  'of ₹${_compact(budget)}',
                                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: cs.outline.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: progressColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: progressColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text('Delete "${project.name}" and all its expenses? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(projectServiceProvider).deleteProject(uid, project.id);
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, String uid, ProjectModel project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProjectSheet(project: project, uid: uid),
    );
  }
}

class _EditProjectSheet extends ConsumerStatefulWidget {
  final ProjectModel project;
  final String uid;
  const _EditProjectSheet({required this.project, required this.uid});

  @override
  ConsumerState<_EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends ConsumerState<_EditProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _budgetCtrl;
  late String _projectType;
  late DateTime _startDate;
  late DateTime? _targetEndDate;
  late ProjectStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.project.name);
    _descCtrl = TextEditingController(text: widget.project.description ?? '');
    _budgetCtrl = TextEditingController(text: widget.project.estimatedBudget.toStringAsFixed(0));
    _projectType = widget.project.projectType;
    _startDate = widget.project.startDate;
    _targetEndDate = widget.project.targetEndDate;
    _status = widget.project.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectServiceProvider).updateProject(widget.uid, widget.project.id, {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'projectType': _projectType,
        'estimatedBudget': double.parse(_budgetCtrl.text.trim()),
        'startDate': Timestamp.fromDate(_startDate),
        'targetEndDate': _targetEndDate != null ? Timestamp.fromDate(_targetEndDate!) : null,
        'status': _status.name,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Form(
            key: _formKey,
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
                    Icon(Icons.edit_outlined, color: primary),
                    const SizedBox(width: 10),
                    Text('Edit Project', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: primary)),
                  ],
                ),
                const SizedBox(height: 20),
                _field(_nameCtrl, 'Project Name', Icons.folder_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter project name' : null),
                const SizedBox(height: 14),
                _field(_descCtrl, 'Description (optional)', Icons.description_outlined, maxLines: 2),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _projectTypes.contains(_projectType) ? _projectType : _projectTypes.last,
                  decoration: _dec('Project Type', Icons.category_outlined),
                  items: _projectTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _projectType = v!),
                ),
                const SizedBox(height: 14),
                _field(_budgetCtrl, 'Estimated Budget (₹)', Icons.account_balance_wallet_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter budget';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                      return null;
                    }),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _DateTile(label: 'Start Date', date: _startDate, onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (p != null) setState(() => _startDate = p);
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _DateTile(label: 'Target End', date: _targetEndDate, onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: _targetEndDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (p != null) setState(() => _targetEndDate = p);
                    }, onClear: _targetEndDate != null ? () => setState(() => _targetEndDate = null) : null)),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ProjectStatus>(
                  value: _status,
                  decoration: _dec('Status', Icons.flag_outlined),
                  items: ProjectStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name[0].toUpperCase() + s.name.substring(1)))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(label, icon),
      validator: validator,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateTile({required this.label, required this.date, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  Text(date != null ? DateFormat('dd MMM yy').format(date!) : 'Not set', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.construction_rounded,
      title: 'No projects yet',
      subtitle: 'Track budgets and expenses for construction, weddings, renovations & more',
      actionLabel: 'Create Project',
      onAction: () => context.push('/projects/create'),
    );
  }
}

