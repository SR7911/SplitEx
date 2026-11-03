import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/domain/projections/calendar/payment_calendar_event.dart';
import 'package:split_ex/modules/personal/domain/projections/dashboard/personal_attention.dart';
import 'package:split_ex/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart';
import 'package:split_ex/modules/personal/presentation/budgets/providers/personal_budget_providers.dart';
import 'package:split_ex/modules/personal/presentation/calendar/providers/payment_calendar_provider.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';

/// Uses calendar days, and updates a dashboard left open across midnight.
final personalAttentionTodayProvider = Provider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(tomorrow.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return paymentDay(now);
});

final personalAttentionPaymentsProvider = Provider.autoDispose
    .family<AsyncValue<List<PaymentCalendarEvent>>, DateTime>((
      ref,
      selectedMonth,
    ) {
      final today = ref.watch(personalAttentionTodayProvider);
      final month = DateTime(selectedMonth.year, selectedMonth.month);
      final isCurrentMonth =
          month.year == today.year && month.month == today.month;
      if (!isCurrentMonth) {
        final state = ref.watch(paymentCalendarProvider(month));
        return _project(
          [state],
          () => upcomingAttentionPayments(
            state.requireValue,
            month,
            days: DateTime(month.year, month.month + 1, 0).day,
          ),
        );
      }
      final lastDay = DateTime(today.year, today.month, today.day + 6);
      final states = [ref.watch(paymentCalendarProvider(month))];
      if (lastDay.month != month.month || lastDay.year != month.year) {
        states.add(
          ref.watch(
            paymentCalendarProvider(DateTime(lastDay.year, lastDay.month)),
          ),
        );
      }
      return _project(
        states,
        () => upcomingAttentionPayments(
          states.expand((state) => state.requireValue),
          today,
        ),
      );
    });

final personalAttentionBudgetsProvider = Provider.autoDispose
    .family<AsyncValue<List<PersonalBudgetOverrun>>, DateTime>((ref, month) {
      final monthKey = DateFormat('yyyy-MM').format(month);
      final budgets = ref.watch(personalMonthBudgetsProvider(monthKey));
      final transactions = ref.watch(
        personalMonthDisplayTransactionsProvider(monthKey),
      );
      return _project(
        [budgets, transactions],
        () => attentionBudgetOverruns(
          budgets.requireValue,
          calculatePersonalCategorySpending(transactions.requireValue),
        ),
      );
    });

AsyncValue<List<T>> _project<T>(
  List<AsyncValue> sources,
  List<T> Function() build,
) {
  for (final source in sources) {
    if (source.hasError) {
      return AsyncError(source.error!, source.stackTrace ?? StackTrace.current);
    }
  }
  if (sources.any((source) => source.isLoading)) return const AsyncLoading();
  return AsyncData(build());
}
