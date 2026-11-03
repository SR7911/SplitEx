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

// ── Semantic helpers ────────────────────────────────────────────────────────

Color _kindColor(BuildContext context, PaymentCalendarKind kind) =>
    switch (kind) {
      PaymentCalendarKind.emi       => Theme.of(context).colorScheme.primary,
      PaymentCalendarKind.recurring => AppColors.warning(context),
      PaymentCalendarKind.debt      => AppColors.success(context),
    };

IconData _kindIcon(PaymentCalendarKind kind) => switch (kind) {
  PaymentCalendarKind.emi       => Icons.account_balance_outlined,
  PaymentCalendarKind.recurring => Icons.autorenew_rounded,
  PaymentCalendarKind.debt      => Icons.handshake_outlined,
};

String _money(double n) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: n == n.roundToDouble() ? 0 : 2,
).format(n);

// ── Screen ──────────────────────────────────────────────────────────────────

class PaymentCalendarScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const PaymentCalendarScreen({super.key, this.initialDate});
  @override
  ConsumerState<PaymentCalendarScreen> createState() =>
      _PaymentCalendarScreenState();
}

class _PaymentCalendarScreenState
    extends ConsumerState<PaymentCalendarScreen> {
  late DateTime _month, _selected;
  PaymentCalendarKind? _filter;
  bool _wholeMonth = false;

  @override
  void initState() {
    super.initState();
    _selected = paymentDay(widget.initialDate ?? DateTime.now());
    _month    = DateTime(_selected.year, _selected.month);
  }

  void _move(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    _selected = now.year == _month.year && now.month == _month.month
        ? paymentDay(now)
        : _month;
  });

  void _today() => setState(() {
    _selected = paymentDay(DateTime.now());
    _month    = DateTime(_selected.year, _selected.month);
  });

  void _retry() {
    final loanIds = (ref.read(personalLoansProvider).valueOrNull ?? [])
        .map((l) => l.id)
        .toList();
    ref.invalidate(personalLoansProvider);
    ref.invalidate(personalRecurringEntriesProvider);
    ref.invalidate(personalDebtTransactionsProvider);
    for (final id in loanIds) ref.invalidate(personalLoanPaymentsProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final state = ref.watch(paymentCalendarProvider(_month));
    final events = (state.valueOrNull ?? [])
        .where((e) => _filter == null || e.kind == _filter)
        .toList();

    final pending  = events.where((e) => !e.recorded);
    final outgoing = pending.where((e) => !e.incoming).fold(0.0, (n, e) => n + e.amount);
    final incoming = pending.where((e) =>  e.incoming).fold(0.0, (n, e) => n + e.amount);
    final overdue  = pending
        .where((e) => e.status(DateTime.now()) == PaymentCalendarStatus.overdue)
        .length;
    final agenda = events
        .where((e) => _wholeMonth || DateUtils.isSameDay(e.date, _selected))
        .toList();

    return Scaffold(
      appBar: AppHeader(
        title: 'Payment Calendar',
        showBack: true,
        showNotification: false,
        trailing: TextButton(
          onPressed: _today,
          child: Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
        ),
      ),
      body: GradientBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, 40),
          children: [
            // ── Summary hero ──────────────────────────────────────────────
            if (!state.hasError)
              _SummaryHero(
                outgoing: state.isLoading ? null : outgoing,
                incoming: state.isLoading ? null : incoming,
                overdue: overdue,
              ),
            if (state.hasError)
              _ErrorBanner(onRetry: _retry),
            const SizedBox(height: AppSpacing.md),

            // ── Calendar card ─────────────────────────────────────────────
            Container(
              decoration: appCardDecoration(context),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Month nav header
                  _CalendarHeader(
                    month: _month,
                    onPrev: () => _move(-1),
                    onNext: () => _move(1),
                    onPickDate: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selected,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _selected = paymentDay(picked);
                          _month    = DateTime(picked.year, picked.month);
                        });
                      }
                    },
                  ),
                  if (state.isLoading)
                    LinearProgressIndicator(minHeight: 2, color: cs.primary),
                  // Day-of-week labels
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                    child: Row(
                      children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: .6,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface.withValues(alpha: .4),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Grid
                  GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() > 150) _move(v < 0 ? 1 : -1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      child: _MonthGrid(
                        month: _month,
                        selected: _selected,
                        events: events,
                        onSelect: (day) => setState(() {
                          _selected   = day;
                          _wholeMonth = false;
                        }),
                      ),
                    ),
                  ),
                  // Legend
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: PaymentCalendarKind.values.map((kind) {
                        final color = _kindColor(context, kind);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                switch (kind) {
                                  PaymentCalendarKind.emi       => 'EMI',
                                  PaymentCalendarKind.recurring => 'Recurring',
                                  PaymentCalendarKind.debt      => 'Debt',
                                },
                                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: .55), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Filter chips ──────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    icon: Icons.calendar_month_rounded,
                    color: cs.primary,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final kind in PaymentCalendarKind.values)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: _FilterChip(
                        label: switch (kind) {
                          PaymentCalendarKind.emi       => 'EMIs',
                          PaymentCalendarKind.recurring => 'Recurring',
                          PaymentCalendarKind.debt      => 'Debts',
                        },
                        icon: _kindIcon(kind),
                        color: _kindColor(context, kind),
                        selected: _filter == kind,
                        onTap: () => setState(() => _filter = kind),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Agenda header ─────────────────────────────────────────────
            AppSectionHeader(
              title: _wholeMonth
                  ? 'Month Agenda'
                  : DateUtils.isSameDay(_selected, DateTime.now())
                  ? 'Today\'s Agenda'
                  : DateFormat('EEEE, d MMM').format(_selected),
              actionLabel: _wholeMonth ? 'Selected day' : 'Whole month',
              onAction: () => setState(() => _wholeMonth = !_wholeMonth),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${agenda.length} ${agenda.length == 1 ? 'payment' : 'payments'}',
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Agenda list ───────────────────────────────────────────────
            if (!state.isLoading && !state.hasError && agenda.isEmpty)
              Container(
                decoration: appCardDecoration(context),
                child: AppFinanceEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No scheduled payments',
                  subtitle: _wholeMonth
                      ? 'No scheduled payments for this month.'
                      : 'Tap another date to see upcoming payments.',
                ),
              ),
            if (agenda.isNotEmpty)
              Container(
                decoration: appCardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  children: [
                    for (final event in agenda)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PaymentTile(event: event, wholeMonth: _wholeMonth),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Recurring entries marked Recorded follow their last run date. Debt dates are optional.',
              style: AppTextStyles.caption(context).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary hero ─────────────────────────────────────────────────────────────

class _SummaryHero extends StatelessWidget {
  final double? outgoing, incoming;
  final int overdue;
  const _SummaryHero({required this.outgoing, required this.incoming, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.error(context).withValues(alpha: isDark ? .1 : .06),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.error(context).withValues(alpha: .18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.error(context).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  ),
                  child: Icon(Icons.north_east_rounded, size: 16, color: AppColors.error(context)),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    outgoing == null ? '—' : _money(outgoing!),
                    style: AppTextStyles.statSmall(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text('To pay', style: AppTextStyles.caption(context)),
                if (overdue > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error(context).withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$overdue overdue',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error(context)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.success(context).withValues(alpha: isDark ? .1 : .06),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.success(context).withValues(alpha: .18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.success(context).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  ),
                  child: Icon(Icons.south_west_rounded, size: 16, color: AppColors.success(context)),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    incoming == null ? '—' : _money(incoming!),
                    style: AppTextStyles.statSmall(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text('To receive', style: AppTextStyles.caption(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.base),
    decoration: appCardDecoration(context),
    child: Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning(context)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Some schedules could not be loaded.',
            style: AppTextStyles.bodySmall(context),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

// ── Calendar header ───────────────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext, onPickDate;
  const _CalendarHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withValues(alpha: .08), cs.primary.withValues(alpha: .02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev, tooltip: 'Previous month'),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: onPickDate,
              child: Column(
                children: [
                  Text(DateFormat('MMMM').format(month), style: AppTextStyles.sectionTitle(context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${month.year}', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
                      Icon(Icons.expand_more_rounded, size: 15, color: cs.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext, tooltip: 'Next month'),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _NavBtn({required this.icon, required this.onTap, required this.tooltip});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: cs.onSurface.withValues(alpha: .7)),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? .22 : .12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? color.withValues(alpha: .45) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: .5)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

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
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offset = month.weekday - 1;
    final days   = DateTime(month.year, month.month + 1, 0).day;
    final cells  = ((offset + days) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 68,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemBuilder: (context, index) {
        final day = DateTime(month.year, month.month, index - offset + 1);

        // Empty leading/trailing cells — render a faint placeholder so the
        // grid rows stay visually consistent.
        if (day.month != month.month) {
          return Container(
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: isDark ? .03 : .025),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          );
        }

        final chosen  = DateUtils.isSameDay(day, selected);
        final today   = DateUtils.isSameDay(day, DateTime.now());
        final daily   = events.where((e) => DateUtils.isSameDay(e.date, day)).toList();
        final kinds   = daily.map((e) => e.kind).toSet().toList();
        final hasEvents = daily.isNotEmpty;
        final allDone = hasEvents && daily.every((e) => e.recorded);
        final total   = daily.where((e) => !e.recorded).fold(0.0, (n, e) => n + e.amount);

        // Colour logic
        final Color cellBg;
        final Color cellBorder;
        final Color fg;
        if (chosen) {
          cellBg     = cs.primary;
          cellBorder = cs.primary;
          fg         = cs.onPrimary;
        } else if (today) {
          cellBg     = cs.primary.withValues(alpha: isDark ? .18 : .10);
          cellBorder = cs.primary.withValues(alpha: .55);
          fg         = cs.primary;
        } else if (hasEvents) {
          // Subtle tint from the first event kind
          final accent = _kindColor(context, kinds.first);
          cellBg     = accent.withValues(alpha: isDark ? .10 : .06);
          cellBorder = accent.withValues(alpha: isDark ? .25 : .18);
          fg         = cs.onSurface;
        } else {
          cellBg     = isDark
              ? cs.surfaceContainerHigh
              : cs.surface;
          cellBorder = cs.outline.withValues(alpha: .08);
          fg         = cs.onSurface.withValues(alpha: .65);
        }

        return Semantics(
          key: ValueKey('calendar-${DateFormat('yyyy-MM-dd').format(day)}'),
          selected: chosen,
          label: '${DateFormat('d MMMM yyyy').format(day)}, ${daily.length} payments',
          button: true,
          child: GestureDetector(
            onTap: () => onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: cellBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cellBorder, width: chosen ? 0 : 1),
                boxShadow: chosen
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: .30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Day number ──
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1,
                        color: fg,
                        fontWeight: chosen || today ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),

                    // ── Event dots or done icon ──
                    if (hasEvents)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final kind in kinds.take(3))
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: chosen
                                    ? cs.onPrimary.withValues(alpha: .80)
                                    : allDone
                                    ? cs.onSurface.withValues(alpha: .25)
                                    : _kindColor(context, kind),
                              ),
                            ),
                        ],
                      )
                    else
                      const SizedBox(height: 4),

                    // ── Amount or check ──
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
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: chosen
                                ? cs.onPrimary.withValues(alpha: .85)
                                : _kindColor(context, kinds.first),
                          ),
                        ),
                      )
                    else if (allDone)
                      Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: chosen
                            ? cs.onPrimary.withValues(alpha: .6)
                            : AppColors.success(context).withValues(alpha: .6),
                      )
                    else
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Payment tile ──────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final PaymentCalendarEvent event;
  final bool wholeMonth;
  const _PaymentTile({required this.event, required this.wholeMonth});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final color  = _kindColor(context, event.kind);
    final status = event.status(DateTime.now());
    final statusColor = switch (status) {
      PaymentCalendarStatus.recorded  => AppColors.success(context),
      PaymentCalendarStatus.overdue   => AppColors.error(context),
      PaymentCalendarStatus.scheduled => cs.onSurface.withValues(alpha: .45),
    };
    final statusText = switch (status) {
      PaymentCalendarStatus.recorded  => event.debt != null ? 'Closed' : 'Recorded',
      PaymentCalendarStatus.overdue   => 'Overdue',
      PaymentCalendarStatus.scheduled => 'Scheduled',
    };

    return AppFinanceTile(
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                ),
                Text(
                  DateFormat('MMM').format(event.date),
                  style: AppTextStyles.caption(context).copyWith(color: color),
                ),
              ],
            ),
      badges: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _Badge(text: event.kindLabel, color: color),
          _Badge(text: statusText, color: statusColor),
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
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}
