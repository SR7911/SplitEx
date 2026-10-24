import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/personal_account_model.dart';
import 'package:split_ex/providers/personal_account_provider.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

IconData personalAccountIcon(PersonalAccountType type) => switch (type) {
  PersonalAccountType.cash => Icons.payments_outlined,
  PersonalAccountType.bank => Icons.account_balance_outlined,
  PersonalAccountType.creditCard => Icons.credit_card_rounded,
};

class PersonalAccountPicker extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String label;
  final bool requiredAccount;
  const PersonalAccountPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Account',
    this.requiredAccount = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(personalAccountsProvider);
    final accounts = (data.valueOrNull ?? [])
        .where((a) => !a.archived || a.id == value)
        .toList();
    return DropdownButtonFormField<String>(
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
      key: ValueKey('account-$value-${accounts.map((a) => a.id).join()}'),
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.account_balance_wallet_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .5),
        ),
        helperStyle: AppTextStyles.caption(context),
        helperMaxLines: 2,
        labelStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontSize: 14),
        helperText: data.hasError
            ? 'Accounts unavailable. Retry from Accounts & Wallets.'
            : requiredAccount
            ? 'Choose an account for this transfer'
            : 'Optional · manage accounts in Personal',
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Unassigned')),
        if (value != null && !accounts.any((a) => a.id == value))
          DropdownMenuItem(value: value, child: const Text('Saved account')),
        ...accounts.map(
          (a) => DropdownMenuItem(
            value: a.id,
            child: Text(
              '${a.name}${a.archived ? ' (archived)' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: enabled && !data.isLoading && !data.hasError
          ? (v) => onChanged(v == '' ? null : v)
          : null,
    );
  }
}
