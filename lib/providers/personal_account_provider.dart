import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/personal_account_model.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/services/personal_account_service.dart';

final personalAccountServiceProvider = Provider(
  (ref) => PersonalAccountService(),
);
final personalAccountsProvider = StreamProvider<List<PersonalAccount>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return uid == null
      ? Stream.value([])
      : ref.watch(personalAccountServiceProvider).accounts(uid);
});
final personalTransfersProvider = StreamProvider<List<PersonalTransfer>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return uid == null
      ? Stream.value([])
      : ref.watch(personalAccountServiceProvider).transfers(uid);
});
final accountTransactionsProvider =
    StreamProvider<List<PersonalTransactionModel>>((ref) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      return uid == null
          ? Stream.value([])
          : ref.watch(personalAccountServiceProvider).assignedTransactions(uid);
    });
final personalAccountBalancesProvider =
    Provider<AsyncValue<Map<String, double>>>((ref) {
      final accounts = ref.watch(personalAccountsProvider);
      final transfers = ref.watch(personalTransfersProvider);
      final transactions = ref.watch(accountTransactionsProvider);
      for (final state in [accounts, transfers, transactions]) {
        if (state.hasError)
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
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
