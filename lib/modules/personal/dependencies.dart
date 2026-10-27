import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/repositories/personal_account_repository.dart';
import 'domain/repositories/personal_transaction_repository.dart';
import 'domain/repositories/personal_budget_repository.dart';
import 'domain/repositories/personal_recurring_repository.dart';
import 'domain/repositories/personal_recurring_processor.dart';
import 'domain/repositories/personal_loan_repository.dart';
import 'domain/repositories/savings_goal_repository.dart';
import 'domain/repositories/bank_sms_repository.dart';
import 'domain/repositories/merchant_category_repository.dart';

/// Configured by the app composition root, or overridden by a test.
final personalAccountRepositoryProvider = Provider<PersonalAccountRepository>(
  (ref) => throw StateError('Personal account repository is not configured.'),
);

final personalTransactionRepositoryProvider =
    Provider<PersonalTransactionRepository>(
      (ref) => throw StateError(
        'Personal transaction repository is not configured.',
      ),
    );

final personalBudgetRepositoryProvider = Provider<PersonalBudgetRepository>(
  (ref) => throw StateError('Personal budget repository is not configured.'),
);

final personalRecurringRepositoryProvider =
    Provider<PersonalRecurringRepository>(
      (ref) =>
          throw StateError('Personal recurring repository is not configured.'),
    );

final personalRecurringProcessorProvider = Provider<PersonalRecurringProcessor>(
  (ref) => throw StateError('Personal recurring processor is not configured.'),
);

final personalLoanRepositoryProvider = Provider<PersonalLoanRepository>(
  (ref) => throw StateError('Personal loan repository is not configured.'),
);

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>(
  (ref) => throw StateError('Savings goal repository is not configured.'),
);

final bankSmsRepositoryProvider = Provider<PersonalBankSmsRepository>(
  (ref) => throw StateError('Bank SMS repository is not configured.'),
);

final merchantCategoryServiceProvider = Provider<MerchantCategoryRepository>(
  (ref) => throw StateError('Merchant category repository is not configured.'),
);

/// Maps the authentication boundary to a plain user ID, preserving async state.
final personalUserIdProvider = Provider<AsyncValue<String?>>(
  (ref) => throw StateError('Personal session is not configured.'),
);
