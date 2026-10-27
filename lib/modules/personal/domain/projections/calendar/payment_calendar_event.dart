import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_entry.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_payment.dart';

enum PaymentCalendarKind { emi, recurring, debt }

enum PaymentCalendarStatus { scheduled, overdue, recorded }

DateTime paymentDay(DateTime date) => DateTime(date.year, date.month, date.day);

class PaymentCalendarEvent {
  final String id, sourceId, title, subtitle;
  final PaymentCalendarKind kind;
  final DateTime date;
  final double amount;
  final bool incoming, recorded;
  final PersonalTransaction? debt;
  const PaymentCalendarEvent({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.date,
    required this.amount,
    required this.incoming,
    this.recorded = false,
    this.debt,
  });
  PaymentCalendarStatus status(DateTime now) => recorded
      ? PaymentCalendarStatus.recorded
      : paymentDay(date).isBefore(paymentDay(now))
      ? PaymentCalendarStatus.overdue
      : PaymentCalendarStatus.scheduled;
  String get kindLabel => switch (kind) {
    PaymentCalendarKind.emi => 'EMI',
    PaymentCalendarKind.recurring => 'Recurring',
    PaymentCalendarKind.debt => 'Debt',
  };
}

/// A read-only projection: opening the calendar never records a payment.
List<PaymentCalendarEvent> buildPaymentCalendar({
  required DateTime month,
  required List<PersonalLoan> loans,
  required Map<String, List<PersonalLoanPayment>> payments,
  required List<PersonalRecurringEntry> recurring,
  required List<PersonalTransaction> debts,
  required DateTime now,
}) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  bool inMonth(DateTime d) => !d.isBefore(start) && d.isBefore(end);
  final events = <PaymentCalendarEvent>[];
  final linkedRecurring = loans
      .map((l) => l.recurringId)
      .whereType<String>()
      .toSet();
  for (final loan in loans) {
    final logs = [...?payments[loan.id]]
      ..sort((a, b) => a.date.compareTo(b.date));
    final remainingEmis = logs
        .where((p) => p.type == PersonalLoanPaymentType.emi)
        .toList();
    for (var i = 0; i < loan.tenureMonths; i++) {
      final ref = loan.effectiveEmiStart;
      final first = DateTime(ref.year, ref.month + i);
      final due = DateTime(
        first.year,
        first.month,
        loan.emiDueDay.clamp(1, DateTime(first.year, first.month + 1, 0).day),
      );
      // Consume each log once, consistent with the existing missed-EMI check.
      final index = remainingEmis.indexWhere(
        (p) => paymentDay(p.date).difference(due).inDays.abs() <= 15,
      );
      final paid = index < 0 ? null : remainingEmis.removeAt(index);
      if (!inMonth(due)) continue;
      if (paid == null && loan.status != PersonalLoanStatus.active) continue;
      final previous = logs
          .where((p) => !paymentDay(p.date).isAfter(due))
          .lastOrNull;
      if (paid == null &&
          previous != null &&
          previous.remainingPrincipalAfter < 1)
        continue;
      events.add(
        PaymentCalendarEvent(
          id: 'emi-${loan.id}-$i',
          sourceId: loan.id,
          title: loan.title,
          subtitle:
              '${loan.lenderBorrowerName ?? 'Loan'} · Installment ${i + 1} of ${loan.tenureMonths}',
          kind: PaymentCalendarKind.emi,
          date: due,
          amount: paid?.amount ?? loan.baseEmi,
          incoming: loan.loanType == PersonalLoanType.lent,
          recorded: paid != null,
        ),
      );
    }
  }
  for (final r in recurring) {
    if (!r.active || linkedRecurring.contains(r.id)) continue;
    final anchor = paymentDay(
      r.createdAt ?? r.lastRunDate ?? DateTime(now.year, now.month),
    );
    final dates = <DateTime>[];
    if (r.frequency == PersonalRecurringFrequency.monthly) {
      dates.add(
        DateTime(
          start.year,
          start.month,
          r.dayOfMonth.clamp(1, DateTime(start.year, start.month + 1, 0).day),
        ),
      );
    } else {
      final weeklyAnchor = paymentDay(r.lastRunDate ?? r.createdAt ?? now);
      final offset = ((weeklyAnchor.difference(start).inDays % 7) + 7) % 7;
      for (
        var d = start.add(Duration(days: offset));
        d.isBefore(end);
        d = DateTime(d.year, d.month, d.day + 7)
      ) {
        dates.add(d);
      }
    }
    for (final d in dates) {
      if (d.isBefore(anchor) ||
          (r.endDate != null && d.isAfter(paymentDay(r.endDate!))))
        continue;
      events.add(
        PaymentCalendarEvent(
          id: 'recurring-${r.id}-${d.toIso8601String()}',
          sourceId: r.id,
          title: r.title,
          subtitle: '${r.category} · ${r.frequency.name}',
          kind: PaymentCalendarKind.recurring,
          date: d,
          amount: r.amount,
          incoming: r.type == TransactionType.income,
          recorded:
              r.lastRunDate != null && !d.isAfter(paymentDay(r.lastRunDate!)),
        ),
      );
    }
  }
  for (final debt in debts) {
    final due = debt.dueDate;
    if (!debt.hasDebt || due == null || !inMonth(paymentDay(due))) continue;
    events.add(
      PaymentCalendarEvent(
        id: 'debt-${debt.id}',
        sourceId: debt.id,
        title: debt.title,
        subtitle:
            '${debt.personName} · ${debt.debtType == DebtType.lent ? 'To receive' : 'To repay'}',
        kind: PaymentCalendarKind.debt,
        date: paymentDay(due),
        amount: debt.isSettled ? debt.settledAmount : debt.remainingAmount,
        incoming: debt.debtType == DebtType.lent,
        recorded: debt.isSettled,
        debt: debt,
      ),
    );
  }
  events.sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date == 0 ? a.title.compareTo(b.title) : date;
  });
  return events;
}
