import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/recurring/personal_recurring_entry.dart';

final personalRecurringEntriesProvider =
    StreamProvider<List<PersonalRecurringEntry>>((ref) {
      final userId = ref.watch(personalUserIdProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);
      return ref.watch(personalRecurringRepositoryProvider).entries(userId);
    });
