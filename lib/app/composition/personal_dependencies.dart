import 'dart:convert';
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
import 'package:split_ex/modules/personal/data/processors/firestore_personal_recurring_processor.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_personal_loan_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/firestore_savings_goal_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/bank_sms_repository.dart';
import 'package:split_ex/modules/personal/data/repositories/merchant_category_service.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/personal/presentation/sms/controllers/bank_sms_service.dart';

List<Override> personalDependencyOverrides() => [
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
    (ref) => BankSmsRepository(firestore: FirebaseFirestore.instance),
  ),
  merchantCategoryServiceProvider.overrideWith(
    (ref) => MerchantCategoryService(firestore: FirebaseFirestore.instance),
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
    final data = Map<String, dynamic>.from(
      jsonDecode(
        (await BankSmsService.channel.invokeMethod<String>('status'))!,
      ),
    );
    if (user != null && data['owner'] == user.uid && data['enabled'] == true) {
      final service = BankSmsService(repository: BankSmsRepository())
        ..userId = user.uid;
      await service.process();
      retry = service.pendingCount > 0;
      service.dispose();
    }
  } catch (_) {
    retry = true;
  }
  await BankSmsService.channel.invokeMethod<void>('backgroundComplete', {
    'retry': retry,
  });
}
