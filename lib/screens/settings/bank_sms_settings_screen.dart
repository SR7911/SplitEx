import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart'
    show personalCategories;
import 'package:split_ex/services/bank_sms_parser.dart';
import 'package:split_ex/services/bank_sms_repository.dart';
import 'package:split_ex/services/bank_sms_service.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';
import 'package:split_ex/widgets/personal_account_picker.dart';
import 'package:split_ex/widgets/personal_form_sheet.dart';

class BankSmsSettingsScreen extends ConsumerStatefulWidget {
  final bool reviewOnly;
  const BankSmsSettingsScreen({super.key, this.reviewOnly = false});
  @override
  ConsumerState<BankSmsSettingsScreen> createState() =>
      _BankSmsSettingsScreenState();
}

class _BankSmsSettingsScreenState extends ConsumerState<BankSmsSettingsScreen> {
  bool _working = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final service = ref.read(bankSmsServiceProvider);
      await service.refresh();
      if (widget.reviewOnly && service.enabled) await service.process();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update SMS recording. Check your permission and connection.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _enable(BankSmsService service, bool enabled) async {
    if (enabled) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Record payments from bank SMS?'),
          content: const SingleChildScrollView(
            child: Text(
              'SMS access lets SplitEx receive new incoming messages, including when the app is closed. Only financial payment alerts are kept; OTPs and unrelated messages are ignored. Old SMS are not scanned.\n\n'
              'Messages are parsed on this device. Raw SMS and messages awaiting review stay on this device and are excluded from backups. Recorded payment details, including amount, merchant, reference and account ending, sync to your SplitEx account.\n\n'
              'New senders go to Review first. You can trust a sender after checking a message, then auto-record clear future expenses. Credits, transfers and possible duplicate payments require review. You can turn capture off at any time.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (consent != true || !mounted) return;
      await service.requestPermission();
      if (!service.permission) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permission was not granted. Capture remains off.',
              ),
            ),
          );
        return;
      }
    }
    await service.configure(enabled: enabled);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(bankSmsServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final busy = _working || service.busy;
    return Scaffold(
      appBar: AppHeader(
        showBack: true,
        title: widget.reviewOnly ? 'SMS Review Inbox' : 'Bank SMS Recording',
        showNotification: false,
      ),
      body: GradientBody(
        child: !BankSmsService.supported
            ? const Center(
                child: Text('Bank SMS recording is available on Android.'),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!widget.reviewOnly) ...[
                    Container(
                      decoration: appCardDecoration(context),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            secondary: Icon(
                              Icons.sms_outlined,
                              color: cs.onSurface.withValues(alpha: .7),
                              size: 20,
                            ),
                            title: Text(
                              'Capture new bank SMS',
                              style: AppTextStyles.body(context),
                            ),
                            subtitle: Text(
                              'Opt in to detect payments from new messages.',
                              style: AppTextStyles.caption(context),
                            ),
                            value: service.enabled,
                            onChanged: busy
                                ? null
                                : (value) =>
                                      _run(() => _enable(service, value)),
                          ),
                          Divider(
                            height: 1,
                            color: cs.outline.withValues(alpha: .1),
                          ),
                          SwitchListTile.adaptive(
                            title: Text(
                              'Auto-record trusted expenses',
                              style: AppTextStyles.body(context),
                            ),
                            subtitle: Text(
                              'Clear debits from senders you trust. Other payments go to Review.',
                              style: AppTextStyles.caption(context),
                            ),
                            value: service.autoRecord,
                            onChanged: busy || service.userId == null
                                ? null
                                : (value) => _run(
                                    () => service.configure(
                                      enabled: service.enabled,
                                      automatic: value,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      decoration: appCardDecoration(context),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: AppFinanceTile(
                        icon: Icons.mark_email_read_outlined,
                        title: 'Detected Payments',
                        subtitle: service.enabled
                            ? 'Approve, edit, link or dismiss detected payments.'
                            : 'Enable bank SMS capture to receive new payment alerts.',
                        action: IconButton(
                          tooltip: 'SMS settings',
                          onPressed: () => context.push('/settings/bank-sms'),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Background recording needs an internet connection and may be delayed by Android. Pending messages are also checked when you reopen SplitEx.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  if (service.enabled && !service.permission)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'SMS permission is off. Allow it in Android app settings, or disable capture here.',
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  if (service.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        service.error!,
                        style: TextStyle(color: cs.error, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 20),
                  AppSectionHeader(
                    title: 'Review Transactions (${service.reviews.length})',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${service.pendingCount} messages pending processing',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: .6),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: busy || !service.enabled
                            ? null
                            : () => _run(service.process),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Check now'),
                      ),
                    ],
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (service.reviews.isEmpty && !busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AppFinanceEmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'Nothing to review',
                        subtitle:
                            'New senders and uncertain payment alerts will appear here.',
                      ),
                    ),
                  ...service.reviews.map((sms) {
                    final debit = sms.direction == BankSmsDirection.debit;
                    final color = debit
                        ? AppColors.error(context)
                        : AppColors.success(context);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: appCardDecoration(context),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: AppFinanceTile(
                        onTap: busy
                            ? null
                            : () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _BankSmsReviewSheet(sms: sms),
                              ),
                        color: color,
                        icon: debit
                            ? Icons.call_made_rounded
                            : Icons.call_received_rounded,
                        title: sms.title,
                        subtitle:
                            '${sms.sender} · ${DateFormat('dd MMM').format(sms.date)}',
                        value:
                            '₹${NumberFormat('#,##0.##').format(sms.amount)}',
                        detail: debit ? 'Debit' : 'Credit',
                        action: IconButton(
                          tooltip: 'Dismiss message',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: busy
                              ? null
                              : () => _run(() => service.dismiss(sms)),
                        ),
                      ),
                    );
                  }),
                  if (!widget.reviewOnly) ...[
                    const SizedBox(height: 20),
                    AppFinanceTile(
                      icon: Icons.rule_outlined,
                      title: 'Merchant Category Rules',
                      subtitle:
                          'Manage categories remembered for bank SMS payments.',
                      onTap: () => context.push('/personal/merchant-rules'),
                      action: const Icon(Icons.chevron_right_rounded, size: 18),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppSectionHeader(title: 'Trusted Senders'),
                    const SizedBox(height: 10),
                    if (service.trustedSenders.isEmpty)
                      Text(
                        'Verify a message in Review and choose to trust its sender for future expenses.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: cs.onSurface.withValues(alpha: .6),
                        ),
                      ),
                    ...service.trustedSenders.map(
                      (sender) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.verified_user_outlined,
                          color: cs.primary,
                        ),
                        title: Text(
                          sender,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Stop trusting sender',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: busy
                              ? null
                              : () => _run(() => service.trust(sender, false)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

class _BankSmsReviewSheet extends ConsumerStatefulWidget {
  final ParsedBankSms sms;
  const _BankSmsReviewSheet({required this.sms});
  @override
  ConsumerState<_BankSmsReviewSheet> createState() =>
      _BankSmsReviewSheetState();
}

class _BankSmsReviewSheetState extends ConsumerState<_BankSmsReviewSheet> {
  late final TextEditingController _title, _amount;
  late BankSmsDirection _direction;
  late DateTime _date;
  String _category = 'Other';
  String? _accountId;
  String? _fromAccountId, _toAccountId;
  bool _asTransfer = false;
  bool _rememberCategory = false;
  String? _suggestedCategory;
  bool _trust = false, _saving = false, _loading = true;
  String? _decision, _error;
  List<BankSmsMatch> _matches = [];
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.sms.title);
    _amount = TextEditingController(text: widget.sms.amount.toStringAsFixed(2));
    _direction = widget.sms.direction;
    _date = widget.sms.date;
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final uid = ref.read(bankSmsServiceProvider).userId;
    try {
      if (uid == null) throw StateError('Sign in to record this payment.');
      final repo = ref.read(bankSmsRepositoryProvider);
      final matches = await repo.possibleMatches(uid, widget.sms);
      final suggestion = await repo.suggestedCategory(uid, widget.sms);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _suggestedCategory = suggestion;
        if (suggestion != null) _category = suggestion;
        _decision = matches.isEmpty ? 'new' : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _error =
              'Could not check existing transactions. Connect to the internet and reopen this review.';
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text);
    if (_asTransfer &&
        _decision == 'new' &&
        (_fromAccountId == null ||
            _toAccountId == null ||
            _fromAccountId == _toAccountId)) {
      setState(
        () => _error = 'Choose two different accounts for this transfer.',
      );
      return;
    }
    if (_decision == null ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        _title.text.trim().isEmpty) {
      setState(
        () => _error =
            'Enter a title and amount, then choose whether to create or link this payment.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(bankSmsServiceProvider)
          .approve(
            widget.sms,
            title: _title.text.trim(),
            amount: amount,
            category: _category,
            date: _date,
            direction: _direction,
            accountId: _accountId,
            asTransfer: _asTransfer,
            fromAccountId: _fromAccountId,
            toAccountId: _toAccountId,
            existingId: _decision == 'new'
                ? null
                : _decision?.replaceFirst(RegExp(r'^transfer:'), ''),
            trustSender: _trust,
            rememberCategory:
                _rememberCategory &&
                !_asTransfer &&
                _decision == 'new' &&
                _direction == BankSmsDirection.debit,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == BankSmsSaveResult.duplicate
                ? 'Already recorded. No duplicate was added.'
                : _decision == 'new'
                ? 'Payment recorded'
                : 'Linked to the existing transaction',
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        setState(() {
          _error =
              'Could not save. Check your connection and try again. This message has been kept for review.';
          _saving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sms = widget.sms;
    final cs = Theme.of(context).colorScheme;
    final linked = _decision != null && _decision != 'new';
    return PersonalFormSheet(
      title: 'Review bank payment',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${sms.sender}${sms.accountLast4 == null ? '' : ' · Account ending ${sms.accountLast4}'}',
            style: AppTextStyles.label(context).copyWith(color: cs.primary),
          ),
          if (sms.reference != null)
            Text(
              'Reference: ${sms.reference}',
              style: AppTextStyles.caption(context),
            ),
          const SizedBox(height: 12),
          ...sms.reviewReasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $reason',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: .7),
                ),
              ),
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Original message',
              style: TextStyle(fontSize: 13),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  sms.body,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'A similar payment exists. Link it to avoid counting it twice.',
              style: TextStyle(fontSize: 12),
            ),
            DropdownButtonFormField<String>(
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
              initialValue: _decision,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Create or link transaction',
              ),
              items: [
                const DropdownMenuItem(
                  value: 'new',
                  child: Text('Create a separate transaction'),
                ),
                ..._matches.map(
                  (m) => DropdownMenuItem(
                    value: m.isTransfer ? 'transfer:${m.id}' : m.id,
                    child: Text(
                      '${m.isTransfer ? 'Transfer: ' : ''}${m.title} · ${DateFormat('dd MMM').format(m.date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _decision = value;
                      if (value != null && value != 'new') {
                        _asTransfer = value.startsWith('transfer:');
                        _direction = sms.direction;
                        _amount.text = sms.amount.toStringAsFixed(2);
                      }
                    }),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            enabled: !_saving && !linked,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            enabled: !_saving && !linked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 14),
          if (!linked && !_asTransfer) ...[
            PersonalAccountPicker(
              value: _accountId,
              enabled: !_saving,
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 14),
          ],
          if (!linked && _asTransfer) ...[
            PersonalAccountPicker(
              value: _fromAccountId,
              label: 'From account',
              requiredAccount: true,
              enabled: !_saving,
              onChanged: (v) => setState(() => _fromAccountId = v),
            ),
            const SizedBox(height: 14),
            PersonalAccountPicker(
              value: _toAccountId,
              label: 'To account',
              requiredAccount: true,
              enabled: !_saving,
              onChanged: (v) => setState(() => _toAccountId = v),
            ),
            const SizedBox(height: 14),
            const Text(
              'Transfers move money between your own accounts without adding income or spending.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
            key: ValueKey('direction-$_decision'),
            initialValue: _asTransfer ? 'transfer' : _direction.name,
            items: const [
              DropdownMenuItem(value: 'debit', child: Text('Expense')),
              DropdownMenuItem(value: 'credit', child: Text('Income')),
              DropdownMenuItem(
                value: 'transfer',
                child: Text('Transfer between my accounts'),
              ),
            ],
            onChanged: _saving || linked
                ? null
                : (value) => setState(() {
                    _asTransfer = value == 'transfer';
                    if (!_asTransfer)
                      _direction = BankSmsDirection.values.byName(value!);
                  }),
          ),
          const SizedBox(height: 14),
          if (!_asTransfer)
            DropdownButtonFormField<String>(
              key: ValueKey('merchant-category-$_suggestedCategory'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 14),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: {
                ...personalCategories,
                _category,
              }.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _saving || linked || _loading
                  ? null
                  : (value) => setState(() => _category = value!),
            ),
          if (!_asTransfer &&
              !linked &&
              _direction == BankSmsDirection.debit &&
              sms.merchant != null) ...[
            if (_suggestedCategory != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Suggested from your merchant rule.',
                  style: AppTextStyles.caption(context),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Use this category for future payments',
                style: TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${sms.merchant} · ${sms.sender}',
                style: AppTextStyles.caption(context),
              ),
              value: _rememberCategory,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _rememberCategory = v == true),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_month_outlined, color: cs.primary),
            title: const Text('Transaction date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
            onTap: _saving || linked
                ? null
                : () async {
                    final firstDate = DateTime(2000);
                    final lastDate = DateTime.now().add(
                      const Duration(days: 1),
                    );
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _date.isAfter(lastDate)
                          ? lastDate
                          : _date.isBefore(firstDate)
                          ? firstDate
                          : _date,
                      firstDate: firstDate,
                      lastDate: lastDate,
                    );
                    if (date != null && mounted) setState(() => _date = date);
                  },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Trust this sender for future clear expenses',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Credits, possible transfers and duplicate matches still need review.',
              style: TextStyle(fontSize: 11),
            ),
            value: _trust,
            onChanged: _saving
                ? null
                : (value) => setState(() => _trust = value == true),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _loading || _decision == null ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : linked
                  ? 'Link Existing Transaction'
                  : 'Record Transaction',
            ),
          ),
        ],
      ),
    );
  }
}
