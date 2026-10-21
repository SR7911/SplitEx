import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/payment_calendar_model.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/providers/personal_expense_provider.dart';

final paymentCalendarProvider =
    Provider.family<AsyncValue<List<PaymentCalendarEvent>>, DateTime>((
      ref,
      month,
    ) {
      final loans = ref.watch(loansProvider);
      final recurring = ref.watch(personalRecurringProvider);
      final debts = ref.watch(personalDebtsProvider);
      final states = <AsyncValue>[loans, recurring, debts];
      final payments = <String, List<LoanPaymentModel>>{};
      for (final loan in loans.valueOrNull ?? <LoanModel>[]) {
        final logs = ref.watch(loanPaymentsProvider(loan.id));
        states.add(logs);
        payments[loan.id] = logs.valueOrNull ?? [];
      }
      for (final state in states) {
        if (state.hasError)
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
      }
      if (states.any((s) => s.isLoading)) return const AsyncLoading();
      return AsyncData(
        buildPaymentCalendar(
          month: month,
          loans: loans.requireValue,
          payments: payments,
          recurring: recurring.requireValue,
          debts: debts.requireValue,
          now: DateTime.now(),
        ),
      );
    });
