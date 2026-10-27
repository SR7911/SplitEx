import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/projections/calendar/payment_calendar_event.dart';
import 'package:split_ex/modules/personal/presentation/calendar/providers/payment_calendar_provider.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/recurring/providers/personal_recurring_providers.dart';
import 'package:split_ex/modules/personal/presentation/loans/providers/personal_loan_providers.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/view_personal_transaction_sheet.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

Color _kindColor(BuildContext context, PaymentCalendarKind kind) =>
    switch (kind) {
      PaymentCalendarKind.emi => Theme.of(context).colorScheme.primary,
      PaymentCalendarKind.recurring => AppColors.warning(context),
      PaymentCalendarKind.debt => AppColors.success(context),
    };
IconData _kindIcon(PaymentCalendarKind kind) => switch (kind) {
  PaymentCalendarKind.emi => Icons.account_balance_outlined,
  PaymentCalendarKind.recurring => Icons.autorenew_rounded,
  PaymentCalendarKind.debt => Icons.handshake_outlined,
};
String _money(double n) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: n == n.roundToDouble() ? 0 : 2,
).format(n);

class PaymentCalendarScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const PaymentCalendarScreen({super.key, this.initialDate});
  @override
  ConsumerState<PaymentCalendarScreen> createState() =>
      _PaymentCalendarScreenState();
}

class _PaymentCalendarScreenState extends ConsumerState<PaymentCalendarScreen> {
  late DateTime _month, _selected;
  PaymentCalendarKind? _filter;
  bool _wholeMonth = false;
  @override
  void initState() {
    super.initState();
    _selected = paymentDay(widget.initialDate ?? DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
  }

  void _move(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    final today = DateTime.now();
    _selected = today.year == _month.year && today.month == _month.month
        ? paymentDay(today)
        : _month;
  });
  void _today() => setState(() {
    _selected = paymentDay(DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
  });
  void _retry() {
    final loanIds = (ref.read(personalLoansProvider).valueOrNull ?? [])
        .map((loan) => loan.id)
        .toList();
    ref.invalidate(personalLoansProvider);
    ref.invalidate(personalRecurringEntriesProvider);
    ref.invalidate(personalDebtTransactionsProvider);
    for (final id in loanIds) {
      ref.invalidate(personalLoanPaymentsProvider(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(paymentCalendarProvider(_month));
    final events = (state.valueOrNull ?? [])
        .where((e) => _filter == null || e.kind == _filter)
        .toList();
    final pending = events.where((e) => !e.recorded);
    final outgoing = pending
        .where((e) => !e.incoming)
        .fold(0.0, (n, e) => n + e.amount);
    final incoming = pending
        .where((e) => e.incoming)
        .fold(0.0, (n, e) => n + e.amount);
    final agenda = events
        .where((e) => _wholeMonth || DateUtils.isSameDay(e.date, _selected))
        .toList();
    final overdue = pending
        .where((e) => e.status(DateTime.now()) == PaymentCalendarStatus.overdue)
        .length;
    return Scaffold(
      appBar: const AppHeader(
        title: 'Payment Calendar',
        showBack: true,
        showNotification: false,
      ),
      body: GradientBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            AppSectionHeader(
              title: 'Scheduled Payments',
              actionLabel: 'Today',
              onAction: _today,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'EMIs, recurring payments and debt repayments',
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    labelStyle: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: cs.primary),
                    label: const Text('All payments'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final kind in PaymentCalendarKind.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        labelStyle: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: cs.primary),
                        avatar: Icon(
                          _kindIcon(kind),
                          size: 15,
                          color: _kindColor(context, kind),
                        ),
                        label: Text(switch (kind) {
                          PaymentCalendarKind.emi => 'EMIs',
                          PaymentCalendarKind.recurring => 'Recurring',
                          PaymentCalendarKind.debt => 'Debts',
                        }),
                        selected: _filter == kind,
                        onSelected: (_) => setState(() => _filter = kind),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: appCardDecoration(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary.withValues(alpha: .08),
                          cs.primary.withValues(alpha: .02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => _move(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selected,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2200),
                              );
                              if (picked != null && mounted)
                                setState(() {
                                  _selected = paymentDay(picked);
                                  _month = DateTime(picked.year, picked.month);
                                });
                            },
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('MMMM').format(_month),
                                  style: AppTextStyles.sectionTitle(context),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${_month.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.primary,
                                      ),
                                    ),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      size: 16,
                                      color: cs.primary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: () => _move(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (state.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final speed = details.primaryVelocity ?? 0;
                      if (speed.abs() > 150) _move(speed < 0 ? 1 : -1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final day in const [
                                'MON',
                                'TUE',
                                'WED',
                                'THU',
                                'FRI',
                                'SAT',
                                'SUN',
                              ])
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: .5,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface.withValues(
                                          alpha: .45,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _MonthGrid(
                            month: _month,
                            selected: _selected,
                            events: events,
                            onSelect: (day) => setState(() {
                              _selected = day;
                              _wholeMonth = false;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final kind in PaymentCalendarKind.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kindColor(context, kind),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  switch (kind) {
                                    PaymentCalendarKind.emi => 'EMI',
                                    PaymentCalendarKind.recurring =>
                                      'Recurring',
                                    PaymentCalendarKind.debt => 'Debt',
                                  },
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSurface.withValues(alpha: .6),
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
            const SizedBox(height: AppSpacing.md),
            if (state.hasError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: appCardDecoration(context),
                child: Column(
                  children: [
                    const Text(
                      'Some payment schedules could not be loaded. Amounts will appear after retrying.',
                    ),
                    TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _MonthTotal(
                      label: 'To pay',
                      amount: state.isLoading ? null : outgoing,
                      icon: Icons.north_east_rounded,
                      color: AppColors.error(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MonthTotal(
                      label: 'To receive',
                      amount: state.isLoading ? null : incoming,
                      icon: Icons.south_west_rounded,
                      color: AppColors.success(context),
                    ),
                  ),
                ],
              ),
            if (overdue > 0 && !state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.error(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$overdue unrecorded ${overdue == 1 ? 'payment' : 'payments'} before today in this month',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: _wholeMonth
                  ? 'Month Agenda'
                  : DateUtils.isSameDay(_selected, DateTime.now())
                  ? 'Today’s Agenda'
                  : DateFormat('EEEE, d MMM').format(_selected),
              actionLabel: _wholeMonth ? 'Selected day' : 'Whole month',
              onAction: () => setState(() => _wholeMonth = !_wholeMonth),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${agenda.length} ${agenda.length == 1 ? 'payment' : 'payments'}',
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: 12),
            if (!state.isLoading && !state.hasError && agenda.isEmpty)
              Container(
                decoration: appCardDecoration(context),
                child: AppFinanceEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No scheduled payments',
                  subtitle: _wholeMonth
                      ? 'No scheduled payments for this month. Add recurring payments or set a debt repayment date.'
                      : 'Tap another date to see your upcoming payments.',
                ),
              ),
            if (agenda.isNotEmpty)
              Container(
                decoration: appCardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  children: [
                    for (final event in agenda)
                      _PaymentTile(event: event, wholeMonth: _wholeMonth),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Recurring entries marked Recorded follow their last run date. Future amounts reflect the current schedule. Debt dates are optional.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: .5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTotal extends StatelessWidget {
  final String label;
  final double? amount;
  final IconData icon;
  final Color color;
  const _MonthTotal({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: appCardDecoration(context),
    padding: const EdgeInsets.all(AppSpacing.base),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount == null ? '—' : _money(amount!),
            style: AppTextStyles.statSmall(context),
          ),
        ),
      ],
    ),
  );
}

class _MonthGrid extends StatelessWidget {
  final DateTime month, selected;
  final List<PaymentCalendarEvent> events;
  final ValueChanged<DateTime> onSelect;
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days) / 7).ceil() * 7;
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 64,
        crossAxisSpacing: 3,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final day = DateTime(month.year, month.month, index - offset + 1);
        if (day.month != month.month) return const SizedBox();
        final chosen = DateUtils.isSameDay(day, selected);
        final today = DateUtils.isSameDay(day, DateTime.now());
        final daily = events
            .where((e) => DateUtils.isSameDay(e.date, day))
            .toList();
        final kinds = daily.map((e) => e.kind).toSet();
        final total = daily
            .where((e) => !e.recorded)
            .fold(0.0, (n, e) => n + e.amount);
        final foreground = chosen ? cs.onPrimary : cs.onSurface;
        return Semantics(
          selected: chosen,
          label:
              '${DateFormat('d MMMM yyyy').format(day)}, ${daily.length} payments',
          button: true,
          child: InkWell(
            key: ValueKey('calendar-${DateFormat('yyyy-MM-dd').format(day)}'),
            onTap: () => onSelect(day),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: chosen
                    ? cs.primary
                    : today
                    ? cs.primary.withValues(alpha: .06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: today && !chosen
                      ? cs.primary.withValues(alpha: .5)
                      : Colors.transparent,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      color: foreground,
                      fontWeight: chosen || today
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final kind in kinds)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: chosen
                                  ? cs.onPrimary.withValues(alpha: .85)
                                  : _kindColor(context, kind),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (total > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        NumberFormat.compactCurrency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 0,
                        ).format(total),
                        style: TextStyle(
                          fontSize: 10,
                          color: foreground.withValues(alpha: .75),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (daily.isNotEmpty)
                    Icon(
                      Icons.done_rounded,
                      size: 12,
                      color: foreground.withValues(alpha: .55),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentCalendarEvent event;
  final bool wholeMonth;
  const _PaymentTile({required this.event, required this.wholeMonth});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _kindColor(context, event.kind);
    final status = event.status(DateTime.now());
    final statusText = switch (status) {
      PaymentCalendarStatus.recorded =>
        event.debt != null ? 'Closed / settled' : 'Recorded',
      PaymentCalendarStatus.overdue => 'Overdue',
      PaymentCalendarStatus.scheduled => 'Scheduled',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppFinanceTile(
        icon: _kindIcon(event.kind),
        color: color,
        title: event.title,
        subtitle: event.subtitle,
        value: _money(event.amount),
        valueColor: cs.onSurface,
        detail: event.incoming ? 'To receive' : 'To pay',
        leading: !wholeMonth
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${event.date.day}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(event.date),
                    style: AppTextStyles.caption(
                      context,
                    ).copyWith(color: color),
                  ),
                ],
              ),
        badges: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _Tag(text: event.kindLabel, color: color),
            _Tag(
              text: statusText,
              color: status == PaymentCalendarStatus.overdue
                  ? AppColors.error(context)
                  : cs.onSurface.withValues(alpha: .5),
            ),
          ],
        ),
        onTap: () {
          if (event.debt != null) {
            showPersonalTransactionDetail(context, event.debt!);
          } else {
            context.push(
              event.kind == PaymentCalendarKind.emi
                  ? '/personal/loans/${event.sourceId}'
                  : '/personal/recurring',
            );
          }
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
    ),
  );
}
