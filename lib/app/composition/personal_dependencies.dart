import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_account_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_transaction_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_budget_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_recurring_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_recurring_processor.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_loan_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_savings_goal_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_bank_sms_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_merchant_category_repository.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/data/datasources/method_channel_bank_sms_data_source.dart';
import 'package:split_ex/modules/personal/domain/use_cases/sms/process_bank_sms_queue.dart';

List<Override> personalDependencyOverrides() => [
  bankSmsDeviceGatewayProvider.overrideWith(
    (ref) => MethodChannelBankSmsDataSource(),
  ),
  personalAccountRepositoryProvider.overrideWith(
    (ref) => FirestorePersonalAccountRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
  personalTransactionRepositoryProvider.overrideWith(
    (ref) => FirestorePersonalTransactionRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
  personalBudgetRepositoryProvider.overrideWith(
    (ref) => FirestorePersonalBudgetRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
  personalRecurringRepositoryProvider.overrideWith(
    (ref) => FirestorePersonalRecurringRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
  personalRecurringProcessorProvider.overrideWith(
    (ref) => FirestorePersonalRecurringProcessor(
      firestore: FirebaseFirestore.instance,
      transactions: ref.watch(personalTransactionRepositoryProvider),
    ),
  ),
  personalLoanRepositoryProvider.overrideWith(
    (ref) =>
        FirestorePersonalLoanRepository(firestore: FirebaseFirestore.instance),
  ),
  savingsGoalRepositoryProvider.overrideWith(
    (ref) =>
        FirestoreSavingsGoalRepository(firestore: FirebaseFirestore.instance),
  ),
  bankSmsRepositoryProvider.overrideWith(
    (ref) => FirestoreBankSmsRepository(firestore: FirebaseFirestore.instance),
  ),
  merchantCategoryServiceProvider.overrideWith(
    (ref) => FirestoreMerchantCategoryRepository(
      firestore: FirebaseFirestore.instance,
    ),
  ),
  personalUserIdProvider.overrideWith(
    (ref) => ref.watch(authStateProvider).whenData((user) => user?.uid),
  ),
];

@pragma('vm:entry-point')
Future<void> bankSmsBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  var retry = false;
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
    final user = await FirebaseAuth.instance.authStateChanges().first;
    final device = MethodChannelBankSmsDataSource();
    final data = await device.status();
    if (user != null &&
        data['owner'] == user.uid &&
        ((data['enabled'] == true && data['permission'] == true) ||
            (data['rcsEnabled'] == true && data['rcsPermission'] == true))) {
      await ProcessBankSmsQueue(FirestoreBankSmsRepository(), device)(
        userId: user.uid,
        isActive: () => true,
        automatic: () => data['autoRecord'] != false,
        trustedSenders: () => Set<String>.from(data['trustedSenders'] as List),
      );
      final after = await device.status();
      retry = (after['pendingCount'] as num? ?? 0) > 0;
    }
  } catch (_) {
    retry = true;
  }
  await MethodChannelBankSmsDataSource().backgroundComplete(retry);
}
