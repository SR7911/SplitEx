import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';
import 'package:split_ex/screens/personal/add_debt_sheet.dart';
import 'package:split_ex/screens/personal/debt_widgets.dart';
import 'package:split_ex/screens/personal/view_personal_transaction_sheet.dart';
import 'package:split_ex/widgets/app_header.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

class PersonalDebtsScreen extends ConsumerWidget {
  final int initialTab;
  const PersonalDebtsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: const AppHeader(
      showBack: true,
      title: 'All Debts',
      showNotification: false,
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => showAddDebtSheet(context),
      tooltip: 'Add Debt',
      child: const Icon(Icons.add_rounded),
    ),
    body: GradientBody(
      child: ref
          .watch(personalDebtsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load debts: $e')),
            data: (debts) => DefaultTabController(
              length: 3,
              initialIndex: initialTab,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    DebtBalanceSummary(debts: debts),
                    const SizedBox(height: 16),
                    Container(
                      decoration: debtCardDecoration(context),
                      child: const TabBar(
                        tabs: [
                          Tab(text: 'Lent'),
                          Tab(text: 'Borrowed'),
                          Tab(text: 'Settled'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final tab in [0, 1, 2])
                            _DebtTab(
                              debts: debts
                                  .where(
                                    (t) => tab == 2
                                        ? t.isSettled
                                        : !t.isSettled &&
                                              t.debtType ==
                                                  (tab == 0
                                                      ? DebtType.lent
                                                      : DebtType.borrowed),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    ),
  );
}

class DebtBalanceSummary extends StatelessWidget {
  final List<PersonalTransactionModel> debts;
  const DebtBalanceSummary({super.key, required this.debts});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final type in DebtType.values) ...[
        if (type == DebtType.borrowed) const SizedBox(width: 12),
        Expanded(
          child: AppMiniStatCard(
            label: type == DebtType.lent
                ? 'You Lent · Outstanding'
                : 'You Borrowed · Outstanding',
            value:
                '₹${NumberFormat('#,##0.##').format(debts.where((t) => t.debtType == type && !t.isSettled).fold<double>(0, (sum, t) => sum + t.remainingAmount))}',
            icon: type == DebtType.lent
                ? Icons.call_made_rounded
                : Icons.call_received_rounded,
            color: type == DebtType.lent
                ? AppColors.success(context)
                : AppColors.error(context),
          ),
        ),
      ],
    ],
  );
}

class _DebtTab extends StatelessWidget {
  final List<PersonalTransactionModel> debts;
  const _DebtTab({required this.debts});
  @override
  Widget build(BuildContext context) {
    final sorted = [...debts]
      ..sort((a, b) {
        final type = a.debtType!.index.compareTo(b.debtType!.index);
        return type != 0 ? type : b.date.compareTo(a.date);
      });
    if (sorted.isEmpty) {
      return const AppEmptyState(
        icon: Icons.handshake_outlined,
        title: 'No debts here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: sorted.length,
      itemBuilder: (_, i) => DebtTile(txn: sorted[i]),
    );
  }
}

class DebtTile extends StatelessWidget {
  final PersonalTransactionModel txn;
  final bool showActions;
  final bool embedded;
  const DebtTile({
    super.key,
    required this.txn,
    this.showActions = true,
    this.embedded = false,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lent = txn.debtType == DebtType.lent;
    final color = txn.isSettled
        ? cs.onSurface.withValues(alpha: .45)
        : lent
        ? AppColors.success(context)
        : AppColors.error(context);
    final status = txn.isSettled
        ? (txn.writtenOffAmount > 0 ? 'Closed' : 'Settled')
        : txn.settledAmount > 0 || txn.writtenOffAmount > 0
        ? 'Partial'
        : null;
    final partiallySettled = !txn.isSettled && txn.settledAmount > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: embedded ? 0 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showPersonalTransactionDetail(context, txn),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? .07 : .04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        lent
                            ? Icons.call_made_rounded
                            : Icons.call_received_rounded,
                        color: color,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.personName ?? 'Unknown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            txn.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: .6),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${lent ? 'Lent' : 'Borrowed'} · ${txn.category} · ${DateFormat('dd MMM').format(txn.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: .4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .42,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (partiallySettled)
                                    TextSpan(
                                      text:
                                          '₹${NumberFormat('#,##0.##').format(txn.amount)}  ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface.withValues(
                                          alpha: .4,
                                        ),
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: cs.onSurface
                                            .withValues(alpha: .4),
                                      ),
                                    ),
                                  TextSpan(
                                    text:
                                        '₹${NumberFormat('#,##0.##').format(txn.isSettled ? txn.amount : txn.remainingAmount)}',
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (showActions && !txn.isSettled)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: FilledButton.icon(
                              onPressed: () => showDebtSettlement(context, txn),
                              icon: Icon(
                                lent
                                    ? Icons.call_received_rounded
                                    : Icons.call_made_rounded,
                                size: 14,
                              ),
                              label: Text(lent ? 'Receive' : 'Repay'),
                              style: FilledButton.styleFrom(
                                backgroundColor: color.withValues(
                                  alpha: dark ? .18 : .1,
                                ),
                                foregroundColor: color,
                                elevation: 0,
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.padded,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide(
                                  color: color.withValues(alpha: .2),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else if (status != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: .45),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showActions)
                      SizedBox(
                        width: 28,
                        child: PopupMenuButton<String>(
                          tooltip: 'Debt actions',
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: .4),
                          ),
                          onSelected: (action) {
                            if (action == 'edit')
                              showPersonalTransactionDetail(context, txn);
                            if (action == 'close')
                              showDebtSettlement(context, txn, close: true);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('View / Edit'),
                            ),
                            if (!txn.isSettled)
                              const PopupMenuItem(
                                value: 'close',
                                child: Text('Close Debt'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (showActions && txn.partialSettlements.isNotEmpty)
                  _DebtSettlementHistory(txn: txn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtSettlementHistory extends StatelessWidget {
  final PersonalTransactionModel txn;
  const _DebtSettlementHistory({required this.txn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lent = txn.debtType == DebtType.lent;
    final accent = lent ? AppColors.success(context) : AppColors.error(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settlement History',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in txn.partialSettlements)
            Builder(
              builder: (context) {
                final writtenOff = entry['type'] == 'writeOff';
                final color = writtenOff ? AppColors.warning(context) : accent;
                final date = DateTime.tryParse(entry['date']?.toString() ?? '');
                final note = (entry['note'] as String? ?? '').trim();
                final label = writtenOff
                    ? 'Written off'
                    : lent
                    ? 'Received'
                    : 'Repaid';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        writtenOff
                            ? Icons.money_off_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 13,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            if (note.isNotEmpty)
                              Text(
                                note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '₹${NumberFormat('#,##0.##').format(entry['amount'] as num? ?? 0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

void showDebtDetailsSheet(
  BuildContext context,
  String title,
  List<PersonalTransactionModel> debts,
) {
  final order = {for (int i = 0; i < debts.length; i++) debts[i].id: i};
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(personalDebtsProvider).valueOrNull ?? debts;
        final items = current.where((t) => order.containsKey(t.id)).toList()
          ..sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
        final outstanding = items
            .where((t) => !t.isSettled)
            .fold<double>(0, (sum, t) => sum + t.remainingAmount);
        return DebtSheetFrame(
          title: title,
          itemCount: items.length,
          extraContentHeight: items.fold<double>(
            0,
            (sum, item) =>
                sum +
                (item.partialSettlements.isEmpty
                    ? 0
                    : 48 + item.partialSettlements.length * 48),
          ),
          subtitle:
              '${items.length} ${items.length == 1 ? 'debt' : 'debts'} · ₹${NumberFormat('#,##0.##').format(outstanding)} outstanding',
          icon: Icons.handshake_outlined,
          child: items.isEmpty
              ? const AppEmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No debts here',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  itemBuilder: (_, index) => DebtTile(txn: items[index]),
                ),
        );
      },
    ),
  );
}

void showDebtSettlement(
  BuildContext context,
  PersonalTransactionModel txn, {
  bool close = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettlementSheet(txn: txn, close: close),
  );
}

class _SettlementSheet extends ConsumerStatefulWidget {
  final PersonalTransactionModel txn;
  final bool close;
  const _SettlementSheet({required this.txn, required this.close});
  @override
  ConsumerState<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends ConsumerState<_SettlementSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save({bool full = false}) async {
    final userId = ref.read(authStateProvider).valueOrNull?.uid;
    if (userId == null) return;
    final amount = double.tryParse(_amount.text);
    if (!widget.close &&
        !full &&
        (amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > widget.txn.remainingAmount)) {
      setState(
        () => _error =
            'Enter an amount up to ₹${widget.txn.remainingAmount.toStringAsFixed(2)}',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(personalExpenseServiceProvider);
      if (widget.close) {
        await service.closeDebt(userId, widget.txn.id);
      } else if (full) {
        await service.settleTransaction(
          userId,
          widget.txn.id,
          settlementDate: _date,
        );
      } else {
        await service.partialSettleTransaction(
          userId,
          widget.txn.id,
          amount!,
          _note.text.trim(),
          settlementDate: _date,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Could not save: $e';
          _busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lent = widget.txn.debtType == DebtType.lent;
    final accent = lent ? AppColors.success(context) : AppColors.error(context);
    InputDecoration field(String label, {String? prefix}) => InputDecoration(
      labelText: label,
      prefixText: prefix,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: .5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    widget.close
                        ? Icons.money_off_rounded
                        : lent
                        ? Icons.call_received_rounded
                        : Icons.call_made_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.close
                        ? 'Close debt?'
                        : lent
                        ? 'Record money received'
                        : 'Record repayment',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!widget.close)
              Text(
                lent
                    ? 'From ${widget.txn.personName ?? 'this person'} · Money you lent'
                    : 'To ${widget.txn.personName ?? 'this person'} · Money you borrowed',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: debtCardDecoration(context),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lent ? 'Still owed to you' : 'You still owe',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  Text(
                    '₹${widget.txn.remainingAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (widget.close) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning(context).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning(context),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.txn.debtType == DebtType.lent
                            ? 'You will lose the unpaid ₹${widget.txn.remainingAmount.toStringAsFixed(2)}. This balance will be written off without recording money received.'
                            : 'The unpaid ₹${widget.txn.remainingAmount.toStringAsFixed(2)} will be written off without recording a payment.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your original transaction and repayment history will be retained.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  height: 1.5,
                ),
              ),
            ] else ...[
              TextField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: field(
                  lent ? 'Amount received' : 'Amount repaid',
                  prefix: '₹ ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                enabled: !_busy,
                decoration: field('Note (optional)'),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Icon(Icons.calendar_month_outlined, color: accent),
                  title: Text(
                    lent ? 'Received date' : 'Repayment date',
                    style: TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy').format(_date),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: _busy
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(
                              widget.txn.date.year,
                              widget.txn.date.month,
                              widget.txn.date.day,
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (selected != null && mounted)
                            setState(() => _date = selected);
                        },
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            if (widget.close)
              FilledButton(
                onPressed: _busy ? null : () => _save(),
                child: Text(_busy ? 'Saving…' : 'Close & Write Off'),
              )
            else ...[
              OutlinedButton(
                onPressed: _busy ? null : () => _save(),
                child: Text(
                  lent ? 'Record Partial Receipt' : 'Record Partial Repayment',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy ? null : () => _save(full: true),
                child: Text(
                  _busy
                      ? 'Saving…'
                      : lent
                      ? 'Mark Fully Received'
                      : 'Mark Fully Repaid',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
