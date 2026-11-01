import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/repositories/group_repository.dart';
import 'domain/repositories/group_expense_repository.dart';
import 'domain/repositories/group_settlement_repository.dart';
import 'presentation/ports/group_reminder_sender.dart';
import 'presentation/ports/group_payee_lookup.dart';
import 'domain/use_cases/join_group.dart';
import 'domain/use_cases/save_group_expense.dart';
import 'domain/use_cases/record_group_settlement.dart';

final groupServiceProvider = Provider<GroupRepository>(
  (ref) => throw StateError('Group repository is not configured.'),
);
final groupFirestoreExpenseRepositoryProvider = Provider<GroupExpenseRepository>(
  (ref) => throw StateError('Group expense repository is not configured.'),
);
final groupFirestoreSettlementRepositoryProvider = Provider<GroupSettlementRepository>(
  (ref) => throw StateError('Group settlement repository is not configured.'),
);
final groupReminderSenderProvider = Provider<GroupReminderSender>(
  (ref) => throw StateError('Group reminder sender is not configured.'),
);
final groupPayeeLookupProvider = Provider<GroupPayeeLookup>(
  (ref) => throw StateError('Group payee lookup is not configured.'),
);
final joinGroupProvider = Provider(
  (ref) => JoinGroup(ref.watch(groupServiceProvider)),
);
final saveGroupExpenseProvider = Provider(
  (ref) => SaveGroupExpense(ref.watch(groupFirestoreExpenseRepositoryProvider)),
);
final recordGroupSettlementProvider = Provider(
  (ref) => RecordGroupSettlement(ref.watch(groupFirestoreSettlementRepositoryProvider)),
);
