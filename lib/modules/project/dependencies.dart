import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/repositories/project_repository.dart';
import 'domain/repositories/project_expense_repository.dart';
import 'domain/use_cases/record_project_partial_payment.dart';
import 'domain/use_cases/settle_project_debt.dart';

final projectServiceProvider = Provider<ProjectRepository>(
  (ref) => throw StateError('Project repository is not configured.'),
);
final projectFirestoreExpenseRepositoryProvider = Provider<ProjectExpenseRepository>(
  (ref) => throw StateError('Project expense repository is not configured.'),
);
final recordProjectPartialPaymentProvider = Provider(
  (ref) =>
      RecordProjectPartialPayment(ref.watch(projectFirestoreExpenseRepositoryProvider)),
);
final settleProjectDebtProvider = Provider(
  (ref) => SettleProjectDebt(ref.watch(projectFirestoreExpenseRepositoryProvider)),
);
