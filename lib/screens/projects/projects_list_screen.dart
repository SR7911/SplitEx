import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/project_model.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

const _projectTypes = [
  'House Construction', 'Renovation', 'Wedding', 'Business Setup',
  'Office Setup', 'Shop Renovation', 'Event', 'Other',
];

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(userProjectsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/projects/create'),
        child: const Icon(Icons.add),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projects) {
          if (projects.isEmpty) return const _EmptyProjectsState();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: projects.length + 1,
            separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 16) : const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == 0) return _ProjectsSummaryHeader(projects: projects);
              return _ProjectCard(project: projects[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSpent = ref.watch(projectTotalSpentProvider(project.id));
    final budget = project.estimatedBudget;
    final progress = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > budget;
    final uid = ref.read(currentUserIdProvider);

    final statusColor = switch (project.status) {
      ProjectStatus.active => Colors.green,
      ProjectStatus.completed => Colors.blue,
      ProjectStatus.paused => Colors.orange,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/projects/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.construction_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(project.projectType, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(project.status.name, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        _showEditSheet(context, ref, uid, project);
                      } else if (v == 'delete') {
                        _confirmDelete(context, ref, uid);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('₹${totalSpent.toStringAsFixed(0)} spent', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('of ₹${budget.toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: isOver ? Colors.red : progress > 0.8 ? Colors.orange : Colors.green,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
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

class _ProjectsSummaryHeader extends ConsumerWidget {
  final List<ProjectModel> projects;
  const _ProjectsSummaryHeader({required this.projects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = projects.where((p) => p.status == ProjectStatus.active).length;
    double totalBudget = 0;
    double totalSpent = 0;
    for (final p in projects) {
      totalBudget += p.estimatedBudget;
      totalSpent += ref.watch(projectTotalSpentProvider(p.id));
    }
    final progress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > totalBudget;
    final progressColor = isOver ? Colors.red : progress > 0.8 ? Colors.orange : Colors.green;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ProjectPill(
                icon: Icons.construction_rounded,
                label: 'Active',
                value: '$activeCount / ${projects.length}',
                color: Theme.of(context).colorScheme.primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProjectPill(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Total Budget',
                value: '₹${totalBudget.toStringAsFixed(0)}',
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProjectPill(
                icon: Icons.receipt_long_rounded,
                label: 'Total Spent',
                value: '₹${totalSpent.toStringAsFixed(0)}',
                color: progressColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Overall budget used', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                  Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: progressColor)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  color: progressColor,
                  minHeight: 6,
                ),
              ),
              if (isOver) ...
                [const SizedBox(height: 4), Text('Over budget by ₹${(totalSpent - totalBudget).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.red))],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Your Projects', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      ],
    );
  }
}

class _ProjectPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _ProjectPill({required this.icon, required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No projects yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Track expenses for construction, weddings, renovations & more',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/projects/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Project'),
            ),
          ],
        ),
      ),
    );
  }
}
