import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/modules/personal/presentation/reports/models/monthly_money_review.dart';
import 'package:split_ex/modules/personal/presentation/budgets/providers/personal_budget_providers.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';

/// Combines domain transaction streams with the current budget source.
final monthlyMoneyReviewProvider = Provider.autoDispose
    .family<AsyncValue<MonthlyMoneyReview>, DateTime>((ref, month) {
      final current = ref.watch(
        personalMonthTransactionsProvider(DateFormat('yyyy-MM').format(month)),
      );
      final previous = ref.watch(
        personalMonthTransactionsProvider(
          DateFormat('yyyy-MM').format(DateTime(month.year, month.month - 1)),
        ),
      );
      final budgets = ref.watch(
        personalMonthBudgetsProvider(DateFormat('yyyy-MM').format(month)),
      );
      final debts = ref.watch(personalDebtTransactionsProvider);
      final states = <AsyncValue>[current, previous, budgets, debts];
      for (final state in states) {
        if (state.hasError) {
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
        }
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
