import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/create_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/edit_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/use_cases/transactions/delete_personal_transaction.dart';
import 'package:split_ex/modules/personal/domain/use_cases/debts/settle_personal_debt.dart';

final createPersonalTransactionProvider = Provider<CreatePersonalTransaction>(
  (ref) => CreatePersonalTransaction(
    ref.watch(personalTransactionRepositoryProvider),
  ),
);

final editPersonalTransactionProvider = Provider<EditPersonalTransaction>(
  (ref) =>
      EditPersonalTransaction(ref.watch(personalTransactionRepositoryProvider)),
);

final deletePersonalTransactionProvider = Provider<DeletePersonalTransaction>(
  (ref) => DeletePersonalTransaction(
    ref.watch(personalTransactionRepositoryProvider),
  ),
);

final settlePersonalDebtProvider = Provider<SettlePersonalDebt>(
  (ref) => SettlePersonalDebt(ref.watch(personalTransactionRepositoryProvider)),
);
