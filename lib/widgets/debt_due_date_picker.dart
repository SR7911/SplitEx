import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class DebtDueDatePicker extends StatelessWidget {
  final DateTime? value;
  final DateTime debtDate;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  const DebtDueDatePicker({
    super.key,
    required this.value,
    required this.debtDate,
    required this.onChanged,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      Icons.event_outlined,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .5),
      size: 20,
    ),
    title: const Text(
      'Repayment date (optional)',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    subtitle: Text(
      value == null
          ? 'Add to your payment calendar'
          : DateFormat('dd MMM yyyy').format(value!),
      style: AppTextStyles.caption(context),
    ),
    trailing: value == null
        ? const Icon(Icons.chevron_right_rounded)
        : IconButton(
            tooltip: 'Clear repayment date',
            onPressed: enabled ? () => onChanged(null) : null,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
    onTap: !enabled
        ? null
        : () async {
            final first = DateUtils.dateOnly(debtDate);
            final suggested = value ?? DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: suggested.isBefore(first) ? first : suggested,
              firstDate: first,
              lastDate: DateTime(first.year + 100),
            );
            if (date != null && context.mounted) onChanged(date);
          },
  );
}
