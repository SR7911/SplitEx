import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_account.dart';
import 'package:split_ex/modules/personal/domain/entities/accounts/personal_transfer.dart';
import 'package:split_ex/modules/personal/presentation/accounts/controllers/account_controller.dart';
import 'package:split_ex/modules/personal/presentation/accounts/providers/personal_account_providers.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/view_personal_transaction_sheet.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/modules/personal/presentation/accounts/widgets/personal_account_picker.dart';
import 'package:split_ex/modules/personal/presentation/shared/widgets/personal_form_sheet.dart';

String _money(double value) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
).format(value);

class PersonalAccountsScreen extends ConsumerWidget {
  const PersonalAccountsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(personalAccountsProvider);
    final balances = ref.watch(personalAccountBalancesProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AppHeader(
        title: 'Accounts & Wallets',
        showBack: true,
        showNotification: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        extendedTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        onPressed: () => _editAccount(context),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: GradientBody(
        child: accounts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(personalAccountsProvider),
              child: const Text('Could not load accounts · Retry'),
            ),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.base,
              AppSpacing.base,
              100,
            ),
            children: [
              Container(
                decoration: appCardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(title: 'Tracked Balance'),
                    const SizedBox(height: AppSpacing.md),
                    balances.when(
                      data: (values) => FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _money(values.values.fold(0.0, (a, b) => a + b)),
                          style: AppTextStyles.stat(context),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => TextButton(
                        onPressed: () {
                          ref.invalidate(accountTransactionsProvider);
                          ref.invalidate(personalTransfersProvider);
                        },
                        child: const Text('Balance unavailable · Retry'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Opening balances and assigned entries. Card debt reduces the total; unassigned entries are excluded.',
                      style: AppTextStyles.caption(
                        context,
                      ).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    FilledButton.tonalIcon(
                      onPressed: items.where((a) => !a.archived).length < 2
                          ? null
                          : () => _editTransfer(context),
                      style: FilledButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Transfer money'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: appCardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  children: [
                    const AppSectionHeader(title: 'Your Accounts'),
                    const SizedBox(height: AppSpacing.md),
                    if (items.isEmpty)
                      const AppFinanceEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No accounts yet',
                        subtitle:
                            'Add cash, bank accounts or credit cards to track your balances.',
                      ),
                    for (final account in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppFinanceTile(
                          onTap: () => _showAccount(context, account),
                          icon: personalAccountIcon(account.type),
                          title: account.name,
                          subtitle:
                              '${account.typeLabel}${account.last4 == null ? '' : ' · ••${account.last4}'}${account.archived ? ' · Archived' : ''}',
                          value: balances.valueOrNull == null
                              ? '—'
                              : _money(balances.requireValue[account.id] ?? 0),
                          valueColor: cs.onSurface,
                          detail: account.type == PersonalAccountType.creditCard
                              ? 'Negative = owed'
                              : 'Tracked balance',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: appCardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(title: 'Transfers'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Transfers between your accounts do not count as income or spending.',
                      style: AppTextStyles.caption(
                        context,
                      ).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ref
                        .watch(personalTransfersProvider)
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => TextButton(
                            onPressed: () =>
                                ref.invalidate(personalTransfersProvider),
                            child: const Text(
                              'Could not load transfers · Retry',
                            ),
                          ),
                          data: (transfers) => Column(
                            children: [
                              if (transfers.isEmpty)
                                const AppFinanceEmptyState(
                                  icon: Icons.swap_horiz_rounded,
                                  title: 'No transfers yet',
                                  subtitle:
                                      'Move money between two of your accounts.',
                                ),
                              for (final t in transfers)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: AppFinanceTile(
                                    onTap: () =>
                                        _editTransfer(context, transfer: t),
                                    icon: Icons.swap_horiz_rounded,
                                    title:
                                        '${_name(items, t.fromAccountId)} → ${_name(items, t.toAccountId)}',
                                    subtitle:
                                        '${DateFormat('dd MMM yyyy').format(t.date)}${t.note?.isNotEmpty == true ? ' · ${t.note}' : ''}',
                                    value: _money(t.amount),
                                    valueColor: cs.onSurface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _name(List<PersonalAccount> accounts, String id) =>
    accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Account';
void _editAccount(BuildContext context, {PersonalAccount? account}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountEditor(account: account),
    );
void _editTransfer(BuildContext context, {PersonalTransfer? transfer}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferEditor(transfer: transfer),
    );

void _showAccount(
  BuildContext context,
  PersonalAccount account,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final transactions = ref.watch(accountTransactionsProvider);
      return PersonalFormSheet(
        title: account.name,
        icon: personalAccountIcon(account.type),
        trailing: IconButton(
          tooltip: 'Edit account',
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () {
            Navigator.pop(context);
            _editAccount(context, account: account);
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${account.typeLabel} · Opening balance ${_money(account.openingBalance)}',
              style: AppTextStyles.bodySmall(context),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              icon: Icon(
                account.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              label: Text(
                account.archived ? 'Restore account' : 'Archive account',
              ),
              onPressed: () async {
                final uid = ref.read(personalUserIdProvider).valueOrNull;
                if (uid == null) return;
                try {
                  await ref
                      .read(accountControllerProvider)
                      .archive(uid, account.id, !account.archived);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not update account. Try again.'),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(title: 'Assigned Transactions'),
            const SizedBox(height: AppSpacing.md),
            transactions.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load transactions'),
              data: (all) {
                final items =
                    all.where((t) => t.accountId == account.id).toList()
                      ..sort((a, b) => b.date.compareTo(a.date));
                return Column(
                  children: [
                    if (items.isEmpty)
                      const AppFinanceEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No assigned transactions',
                        subtitle:
                            'Choose this account when adding or editing a transaction.',
                      ),
                    for (final t in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppFinanceTile(
                          onTap: () =>
                              showPersonalTransactionDetail(context, t),
                          icon: t.isIncome
                              ? Icons.south_rounded
                              : Icons.north_rounded,
                          color: t.isIncome
                              ? AppColors.success(context)
                              : AppColors.error(context),
                          title: t.title,
                          subtitle:
                              '${t.category} · ${DateFormat('dd MMM yyyy').format(t.date)}',
                          value: '${t.isIncome ? '+' : '−'}${_money(t.amount)}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  ),
);

class _AccountEditor extends ConsumerStatefulWidget {
  final PersonalAccount? account;
  const _AccountEditor({this.account});
  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  late final String _id;
  late final TextEditingController _name, _balance, _last4;
  late PersonalAccountType _type;
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _id = a?.id ?? const Uuid().v4();
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(
      text:
          (a?.type == PersonalAccountType.creditCard
                  ? -(a?.openingBalance ?? 0)
                  : a?.openingBalance ?? 0)
              .toStringAsFixed(2),
    );
    _last4 = TextEditingController(text: a?.last4 ?? '');
    _type = a?.type ?? PersonalAccountType.bank;
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _last4.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = ref.read(personalUserIdProvider).valueOrNull;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final value = double.parse(_balance.text.trim());
      await ref
          .read(accountControllerProvider)
          .saveAccount(
            uid,
            PersonalAccount(
              id: _id,
              name: _name.text.trim(),
              type: _type,
              openingBalance: _type == PersonalAccountType.creditCard
                  ? -value
                  : value,
              last4:
                  _type == PersonalAccountType.cash ||
                      _last4.text.trim().isEmpty
                  ? null
                  : _last4.text.trim(),
              archived: widget.account?.archived ?? false,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save account. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PersonalFormSheet(
    title: widget.account == null ? 'Add account' : 'Edit account',
    icon: Icons.account_balance_wallet_outlined,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Account name',
              hintText: 'Cash, salary account, travel card…',
            ),
            validator: (v) =>
                v?.trim().isEmpty != false ? 'Enter a name' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PersonalAccountType>(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Account type'),
            items: PersonalAccountType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(switch (t) {
                      PersonalAccountType.cash => 'Cash',
                      PersonalAccountType.bank => 'Bank account',
                      PersonalAccountType.creditCard => 'Credit card',
                    }),
                  ),
                )
                .toList(),
            onChanged: _saving || widget.account != null
                ? null
                : (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: _type == PersonalAccountType.creditCard
                  ? 'Opening amount owed'
                  : 'Opening balance',
              prefixText: '₹ ',
              helperText: _type == PersonalAccountType.creditCard
                  ? 'Before assigned entries. Use negative for a card credit.'
                  : 'Balance before all transactions assigned to this account.',
            ),
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              return n == null || !n.isFinite ? 'Enter a valid balance' : null;
            },
          ),
          if (_type != PersonalAccountType.cash) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Last four digits (optional)',
                helperText: 'Used to match clear bank SMS to this account.',
              ),
              validator: (v) =>
                  v?.trim().isNotEmpty == true &&
                      !RegExp(r'^\d{4}$').hasMatch(v!.trim())
                  ? 'Enter exactly four digits'
                  : null,
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save account'),
          ),
        ],
      ),
    ),
  );
}

class _TransferEditor extends ConsumerStatefulWidget {
  final PersonalTransfer? transfer;
  const _TransferEditor({this.transfer});
  @override
  ConsumerState<_TransferEditor> createState() => _TransferEditorState();
}

class _TransferEditorState extends ConsumerState<_TransferEditor> {
  late final String _id;
  String? _from, _to, _error;
  late DateTime _date;
  late final TextEditingController _amount, _note;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final t = widget.transfer;
    _id = t?.id ?? const Uuid().v4();
    _from = t?.fromAccountId;
    _to = t?.toAccountId;
    _date = t?.date ?? DateTime.now();
    _amount = TextEditingController(text: t?.amount.toStringAsFixed(2) ?? '');
    _note = TextEditingController(text: t?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    final uid = ref.read(personalUserIdProvider).valueOrNull;
    if (uid == null) return;
    final amount = double.tryParse(_amount.text.trim());
    if (!delete &&
        (_from == null ||
            _to == null ||
            _from == _to ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0)) {
      setState(
        () => _error = 'Choose different accounts and enter a positive amount.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(accountControllerProvider);
      if (delete) {
        await controller.deleteTransfer(uid, widget.transfer!.id);
      } else {
        await controller.saveTransfer(
          uid,
          PersonalTransfer(
            id: _id,
            fromAccountId: _from!,
            toAccountId: _to!,
            amount: amount!,
            date: _date,
            note: _note.text.trim(),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save. Check that both accounts are active, then retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(personalAccountsProvider).valueOrNull ?? [])
        .where((a) => !a.archived || a.id == _from || a.id == _to)
        .toList();
    Widget picker(String label, String? value, ValueChanged<String?> update) =>
        DropdownButtonFormField<String>(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          initialValue: accounts.any((a) => a.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name}${a.archived ? ' (archived)' : ''}'),
                ),
              )
              .toList(),
          onChanged: _saving ? null : update,
        );
    return PersonalFormSheet(
      title: widget.transfer == null ? 'Transfer money' : 'Edit transfer',
      icon: Icons.swap_horiz_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cash withdrawals and credit card repayments are transfers between your own accounts.',
            style: AppTextStyles.caption(context).copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          picker('From account', _from, (v) => setState(() => _from = v)),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.arrow_downward_rounded),
          ),
          picker('To account', _to, (v) => setState(() => _to = v)),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Transfer date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
            onTap: _saving
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) setState(() => _date = date);
                  },
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : () => _save(),
            child: Text(_saving ? 'Saving…' : 'Save transfer'),
          ),
          if (widget.transfer != null)
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete transfer?'),
                          content: const Text(
                            'This removes the transfer from both tracked account balances.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await _save(delete: true);
                    },
              child: const Text('Delete transfer'),
            ),
        ],
      ),
    );
  }
}
