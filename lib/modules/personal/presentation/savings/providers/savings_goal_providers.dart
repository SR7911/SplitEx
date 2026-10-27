import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/savings/savings_goal.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';

export 'package:split_ex/modules/personal/dependencies.dart'
    show savingsGoalRepositoryProvider;

final savingsGoalsProvider = StreamProvider.autoDispose<List<SavingsGoal>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return uid == null
      ? Stream.value([])
      : ref.watch(savingsGoalRepositoryProvider).watch(uid);
});

final savingsEntriesProvider = StreamProvider.autoDispose
    .family<List<SavingsEntry>, String>((ref, id) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      return uid == null
          ? Stream.value([])
          : ref.watch(savingsGoalRepositoryProvider).entries(uid, id);
    });
