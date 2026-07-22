import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/project_provider.dart';
import 'package:split_ex/providers/room_provider.dart';

const _projectTypes = [
  'House Construction', 'Renovation', 'Wedding', 'Business Setup',
  'Office Setup', 'Shop Renovation', 'Event', 'Other',
];

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  String _projectType = _projectTypes.first;
  DateTime _startDate = DateTime.now();
  DateTime? _targetEndDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(currentUserIdProvider);
      final project = await ref.read(projectServiceProvider).createProject(
            uid: uid,
            name: _nameController.text.trim(),
            description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
            projectType: _projectType,
            estimatedBudget: double.parse(_budgetController.text.trim()),
            startDate: _startDate,
            targetEndDate: _targetEndDate,
          );
      if (mounted) {
        context.pop();
        context.push('/projects/${project.id}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(_nameController, 'Project Name', Icons.folder_outlined,
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter project name' : null),
            const SizedBox(height: 16),
            _field(_descController, 'Description (optional)', Icons.description_outlined, maxLines: 2),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _projectType,
              decoration: _dec('Project Type', Icons.category_outlined),
              items: _projectTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _projectType = v!),
            ),
            const SizedBox(height: 16),
            _field(
              _budgetController,
              'Estimated Budget (₹)',
              Icons.account_balance_wallet_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter budget';
                if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (p != null) setState(() => _startDate = p);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'Target End (opt.)',
                    date: _targetEndDate,
                    onTap: () async {
                      final p = await showDatePicker(context: context, initialDate: _targetEndDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                      if (p != null) setState(() => _targetEndDate = p);
                    },
                    onClear: _targetEndDate != null ? () => setState(() => _targetEndDate = null) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _create,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                  Text(
                    date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Not set',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
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
