import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/dependencies.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/room/presentation/config/room_constants.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/policies/split_calculator.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

void showAddExpenseSheet(
  BuildContext context, {
  required String roomId,
  DateTime? initialDate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddExpenseSheet(roomId: roomId, initialDate: initialDate),
  );
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String roomId;
  final DateTime? initialDate;
  const _AddExpenseSheet({required this.roomId, this.initialDate});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = RoomConstants.expenseCategories.first;
  late DateTime _date;
  SplitType _splitType = SplitType.equal;
  List<String> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final room = ref.read(roomStreamProvider(widget.roomId)).valueOrNull;
    if (room == null) return;
    final userId = ref.read(currentUserIdProvider);
    if (!room.canWrite(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This room is read-only for you.')),
      );
      return;
    }

    List<String> splitAmong;
    switch (_splitType) {
      case SplitType.equal:
        splitAmong = room.memberIds;
        break;
      case SplitType.dynamic:
        if (_selectedMembers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one member')),
          );
          return;
        }
        splitAmong = _selectedMembers;
        break;
      case SplitType.oneToOne:
        if (_selectedMembers.length != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select exactly one person')),
          );
          return;
        }
        splitAmong = [_selectedMembers.first];
        break;
    }

    setState(() => _isLoading = true);
    try {
      final expense = ExpenseModel(
        id: '',
        title: _titleCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.trim()),
        category: _category,
        date: _date,
        paidBy: userId,
        splitType: _splitType,
        splitAmong: splitAmong,
        createdBy: userId,
        createdAt: DateTime.now(),
        month: DateFormat('yyyy-MM').format(_date),
      );
      await ref.read(recordRoomExpenseProvider)(widget.roomId, expense);
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomStreamProvider(widget.roomId)).valueOrNull;
    return PersonalFormSheet(
      title: 'Add Expense',
      icon: Icons.add_circle_outline_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Amount
            TextFormField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0)
                  return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Groceries, Electricity',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Category + Date
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: RoomConstants.expenseCategories
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                RoomDateButton(
                  date: _date,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),

            // Split method
            Text(
              'Split Method',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<SplitType>(
              segments: const [
                ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                ButtonSegment(value: SplitType.dynamic, label: Text('Custom')),
                ButtonSegment(
                    value: SplitType.oneToOne, label: Text('1-to-1')),
              ],
              selected: {_splitType},
              onSelectionChanged: (v) => setState(() {
                _splitType = v.first;
                _selectedMembers = [];
              }),
            ),

            // Member picker
            if (_splitType != SplitType.equal && room != null) ...[
              const SizedBox(height: AppSpacing.md),
              RoomMemberPicker(
                memberIds: room.memberIds,
                payerId: ref.read(currentUserIdProvider),
                splitType: _splitType,
                selected: _selectedMembers,
                onChanged: (v) => setState(() => _selectedMembers = v),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class RoomDateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const RoomDateButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outline.withValues(alpha: .15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: cs.onSurface.withValues(alpha: .55)),
            const SizedBox(width: 6),
            Text(DateFormat('dd MMM').format(date),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class RoomMemberPicker extends ConsumerWidget {
  final List<String> memberIds;
  final String payerId;
  final SplitType splitType;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const RoomMemberPicker({
    required this.memberIds,
    required this.payerId,
    required this.splitType,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final membersAsync = ref.watch(userProfilesByIdsProvider(memberIds));
    final nameMap = <String, String>{};
    if (membersAsync.hasValue) {
      for (final m in membersAsync.value!) nameMap[m.uid] = m.name;
    }
    final others = memberIds.where((id) => id != payerId).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.people_alt_rounded,
                size: 16, color: cs.onSurface.withValues(alpha: .55)),
            const SizedBox(width: 6),
            Text(
              splitType == SplitType.oneToOne
                  ? 'Who owes the full amount?'
                  : 'Share with:',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: others.map((id) {
              final isSelected = selected.contains(id);
              return FilterChip(
                label: Text(nameMap[id] ?? id),
                selected: isSelected,
                onSelected: (checked) {
                  if (splitType == SplitType.oneToOne) {
                    onChanged(checked ? [id] : []);
                  } else {
                    onChanged(SplitCalculator.updateDynamicParticipants(
                      selected: selected,
                      payerId: payerId,
                      memberId: id,
                      included: checked,
                    ));
                  }
                },
                selectedColor: cs.primary.withValues(alpha: .18),
                checkmarkColor: cs.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xxl)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
