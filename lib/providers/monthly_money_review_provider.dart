import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/monthly_money_review.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';

final monthlyMoneyReviewProvider = Provider.autoDispose
    .family<AsyncValue<MonthlyMoneyReview>, DateTime>((ref, month) {
      final current = ref.watch(
        personalTransactionsProvider(DateFormat('yyyy-MM').format(month)),
      );
      final previous = ref.watch(
        personalTransactionsProvider(
          DateFormat('yyyy-MM').format(DateTime(month.year, month.month - 1)),
        ),
      );
      final budgets = ref.watch(
        personalBudgetsProvider(DateFormat('yyyy-MM').format(month)),
      );
      final debts = ref.watch(personalDebtsProvider);
      final states = <AsyncValue>[current, previous, budgets, debts];
      for (final state in states) {
        if (state.hasError)
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
      }
      if (states.any((s) => s.isLoading)) return const AsyncLoading();
      return AsyncData(
        MonthlyMoneyReview.build(
          month: month,
          now: DateTime.now(),
          current: current.requireValue,
          previous: previous.requireValue,
          budgets: budgets.requireValue,
          debts: debts.requireValue,
        ),
      );
    });
