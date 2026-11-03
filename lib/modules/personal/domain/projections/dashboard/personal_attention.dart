import '../../entities/budgets/personal_budget.dart';
import '../calendar/payment_calendar_event.dart';

/// Scheduled outgoing entries for today through the following six days.
/// Recorded entries and expected incoming money are not payments to make.
List<PaymentCalendarEvent> upcomingAttentionPayments(
  Iterable<PaymentCalendarEvent> events,
  DateTime today, {
  int days = 7,
}) {
  final start = paymentDay(today);
  final end = DateTime(start.year, start.month, start.day + days);
  final unique = <String, PaymentCalendarEvent>{};
  for (final event in events) {
    final date = paymentDay(event.date);
    if (!event.recorded &&
        !event.incoming &&
        event.amount > 0 &&
        !date.isBefore(start) &&
        date.isBefore(end)) {
      unique[event.id] = event;
    }
  }
  return unique.values.toList()..sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date == 0 ? a.title.compareTo(b.title) : date;
  });
}

class PersonalBudgetOverrun {
  final String category;
  final int excessPaise;

  const PersonalBudgetOverrun({
    required this.category,
    required this.excessPaise,
  });

  double get excess => excessPaise / 100;
}

List<PersonalBudgetOverrun> attentionBudgetOverruns(
  Iterable<PersonalBudget> budgets,
  Map<String, double> spending,
) {
  final overruns = <PersonalBudgetOverrun>[];
  for (final budget in budgets) {
    final excess =
        ((spending[budget.category] ?? 0) * 100).round() -
        (budget.budget * 100).round();
    if (excess > 0) {
      overruns.add(
        PersonalBudgetOverrun(category: budget.category, excessPaise: excess),
      );
    }
  }
  return overruns..sort((a, b) => b.excessPaise.compareTo(a.excessPaise));
}
