import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dependencies.dart';
import '../../../domain/entities/accounts/personal_account.dart';
import '../../../domain/entities/accounts/personal_transfer.dart';
import '../../../domain/entities/transactions/personal_transaction.dart';
import '../../../domain/policies/accounts/account_balance_calculator.dart';

final personalAccountsProvider = StreamProvider<List<PersonalAccount>>((ref) {
  final uid = ref.watch(personalUserIdProvider).valueOrNull;
  return uid == null
      ? Stream.value([])
      : ref.watch(personalAccountRepositoryProvider).accounts(uid);
});

final personalTransfersProvider = StreamProvider<List<PersonalTransfer>>((ref) {
  final uid = ref.watch(personalUserIdProvider).valueOrNull;
  return uid == null
      ? Stream.value([])
      : ref.watch(personalAccountRepositoryProvider).transfers(uid);
});

final accountTransactionsProvider = StreamProvider<List<PersonalTransaction>>((
  ref,
) {
  final uid = ref.watch(personalUserIdProvider).valueOrNull;
  return uid == null
      ? Stream.value([])
      : ref.watch(personalAccountRepositoryProvider).assignedTransactions(uid);
});

final personalAccountBalancesProvider =
    Provider<AsyncValue<Map<String, double>>>((ref) {
      final accounts = ref.watch(personalAccountsProvider);
      final transfers = ref.watch(personalTransfersProvider);
      final transactions = ref.watch(accountTransactionsProvider);
      for (final state in [accounts, transfers, transactions]) {
        if (state.hasError) {
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
        }
        if (state.isLoading) return const AsyncLoading();
      }
      return AsyncData(
        calculateAccountBalances(
          accounts.requireValue,
          transactions.requireValue,
          transfers.requireValue,
        ),
      );
    });
