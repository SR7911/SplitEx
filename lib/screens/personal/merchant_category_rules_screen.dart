import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart'
    show personalCategories;
import 'package:split_ex/services/merchant_category_service.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';
import 'package:split_ex/widgets/personal_form_sheet.dart';

class MerchantCategoryRulesScreen extends ConsumerWidget {
  const MerchantCategoryRulesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: const AppHeader(
      title: 'Merchant Category Rules',
      showBack: true,
      showNotification: false,
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Add merchant rule',
      onPressed: () => _edit(context),
      child: const Icon(Icons.add),
    ),
    body: GradientBody(
      child: ref
          .watch(merchantCategoryRulesProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(merchantCategoryRulesProvider),
                child: const Text('Could not load rules · Retry'),
              ),
            ),
            data: (rules) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  'Rules match the exact merchant and bank sender. They suggest a category in review and categorize future automatic expenses. They do not grant sender trust or change existing entries.',
                  style: AppTextStyles.bodySmall(context).copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  decoration: appCardDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const AppSectionHeader(title: 'Saved Rules'),
                      const SizedBox(height: 12),
                      if (rules.isEmpty)
                        const AppFinanceEmptyState(
                          icon: Icons.rule_outlined,
                          title: 'No merchant rules yet',
                          subtitle:
                              'Remember a category while reviewing an SMS, or add a rule here.',
                        ),
                      for (final rule in rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppFinanceTile(
                            icon: Icons.category_outlined,
                            title: rule.merchant,
                            subtitle:
                                '${rule.sender} · ${rule.category}${rule.enabled ? '' : ' · Paused'}',
                            onTap: () => _edit(context, rule),
                            action: const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                            ),
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

void _edit(BuildContext context, [MerchantCategoryRule? rule]) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RuleEditor(rule: rule),
    );

class _RuleEditor extends ConsumerStatefulWidget {
  final MerchantCategoryRule? rule;
  const _RuleEditor({this.rule});
  @override
  ConsumerState<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends ConsumerState<_RuleEditor> {
  late final TextEditingController _merchant, _sender;
  late String _category;
  late bool _enabled;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _merchant = TextEditingController(text: widget.rule?.merchant ?? '');
    _sender = TextEditingController(text: widget.rule?.sender ?? '');
    _category = widget.rule?.category ?? 'Other';
    _enabled = widget.rule?.enabled ?? true;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(merchantCategoryServiceProvider);
      if (remove) {
        await service.remove(uid, widget.rule!);
      } else {
        await service.save(
          uid,
          MerchantCategoryRule(
            sender: _sender.text,
            merchant: _merchant.text,
            category: _category,
            enabled: _enabled,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error =
              'Could not save. Check the bank sender, merchant and connection.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PersonalFormSheet(
    title: widget.rule == null ? 'Add merchant rule' : 'Edit merchant rule',
    icon: Icons.rule_outlined,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _merchant,
          enabled: !_saving && widget.rule == null,
          decoration: const InputDecoration(
            labelText: 'Merchant',
            helperText: 'Use the merchant name shown in SMS review.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _sender,
          enabled: !_saving && widget.rule == null,
          decoration: const InputDecoration(
            labelText: 'Bank sender',
            hintText: 'e.g. TESTBK',
            helperText: 'Use the bank sender shown in SMS review.',
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _category,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          decoration: const InputDecoration(labelText: 'Category'),
          items: {
            ...personalCategories,
            _category,
          }.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: _saving ? null : (v) => setState(() => _category = v!),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Rule enabled'),
          value: _enabled,
          onChanged: _saving ? null : (v) => setState(() => _enabled = v),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: Text(_saving ? 'Saving…' : 'Save rule'),
        ),
        if (widget.rule != null)
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete rule?'),
                        content: const Text(
                          'Future payments will no longer use this rule. Existing entries keep their categories.',
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
                    if (confirm == true) await _save(remove: true);
                  },
            child: const Text('Delete rule'),
          ),
      ],
    ),
  );
}
