import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/domain/projections/calendar/payment_calendar_event.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/recurring/providers/personal_recurring_providers.dart';
import 'package:split_ex/modules/personal/presentation/loans/providers/personal_loan_providers.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan.dart';
import 'package:split_ex/modules/personal/domain/entities/loans/personal_loan_payment.dart';

final paymentCalendarProvider =
    Provider.family<AsyncValue<List<PaymentCalendarEvent>>, DateTime>((
      ref,
      month,
    ) {
      final loans = ref.watch(personalLoansProvider);
      final recurring = ref.watch(personalRecurringEntriesProvider);
      final debts = ref.watch(personalDebtTransactionsProvider);
      final states = <AsyncValue>[loans, recurring, debts];
      final payments = <String, List<PersonalLoanPayment>>{};
      for (final loan in loans.valueOrNull ?? <PersonalLoan>[]) {
        final logs = ref.watch(personalLoanPaymentsProvider(loan.id));
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
