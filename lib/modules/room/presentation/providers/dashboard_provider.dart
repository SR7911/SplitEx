import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/debt_transaction.dart';
export 'package:split_ex/modules/room/domain/entities/debt_transaction.dart'
    show DebtTransaction;
import 'package:split_ex/modules/room/presentation/providers/bill_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/expense_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/modules/room/domain/policies/balance_service.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'settlement_provider.dart';

final balanceServiceProvider = Provider<BalanceService>(
  (ref) => BalanceService(),
);

final monthLedgerReadyProvider =
    Provider.family<AsyncValue<void>, MonthBalanceKey>((ref, key) {
      final states = <AsyncValue<Object?>>[
        ref.watch(roomStreamProvider(key.roomId)),
        ref.watch(
          monthExpensesProvider(
            MonthRoomKey(roomId: key.roomId, month: key.month),
          ),
        ),
        ref.watch(
          billsStreamProvider(
            MonthBillKey(roomId: key.roomId, month: key.month),
          ),
        ),
        ref.watch(settlementsStreamProvider(key.roomId)),
      ];
      for (final state in states) {
        if (state.hasError)
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
      }
      if (states.any((s) => s.isLoading)) return const AsyncLoading();
      return const AsyncData(null);
    });

final monthOverallBalanceStateProvider =
    Provider.family<AsyncValue<double>, String>((ref, month) {
      final rooms = ref.watch(userRoomsProvider);
      if (rooms.hasError)
        return AsyncError(rooms.error!, rooms.stackTrace ?? StackTrace.current);
      if (rooms.isLoading) return const AsyncLoading();
      var loading = false;
      for (final room in rooms.valueOrNull ?? []) {
        final state = ref.watch(
          monthLedgerReadyProvider(
            MonthBalanceKey(roomId: room.id, month: month),
          ),
        );
        if (state.hasError)
          return AsyncError(
            state.error!,
            state.stackTrace ?? StackTrace.current,
          );
        loading = loading || state.isLoading;
      }
      if (loading) return const AsyncLoading();
      return AsyncData(ref.watch(monthOverallBalanceProvider(month)));
    });

/// Key for month-specific balance queries.
class MonthBalanceKey {
  final String roomId;
  final String month; // 'yyyy-MM'
  const MonthBalanceKey({required this.roomId, required this.month});

  @override
  bool operator ==(Object other) =>
      other is MonthBalanceKey &&
      roomId == other.roomId &&
      month == other.month;

  @override
  int get hashCode => Object.hash(roomId, month);
}

final netBalancesProvider = Provider.family<Map<String, double>, String>((
  ref,
  roomId,
) {
  final expenses = ref.watch(expensesStreamProvider(roomId)).valueOrNull ?? [];
  final month = ref.watch(currentMonthProvider);
  final bills =
      ref
          .watch(
            billsStreamProvider(MonthBillKey(roomId: roomId, month: month)),
          )
          .valueOrNull ??
      [];
  final room = ref.watch(roomStreamProvider(roomId)).valueOrNull;
  final memberIds = room?.historicalMemberIds ?? [];

  return ref
      .watch(balanceServiceProvider)
      .computeNetBalances(
        expenses: expenses,
        bills: bills,
        memberIds: memberIds,
        legacyBillMemberIds: room?.billFallbackMemberIds,
        settlements:
            (ref.watch(settlementsStreamProvider(roomId)).valueOrNull ?? [])
                .where((s) => s.effectiveMonth == month)
                .toList(),
      );
});

/// Net balances for a room filtered by a specific month.
final monthNetBalancesProvider =
    Provider.family<Map<String, double>, MonthBalanceKey>((ref, key) {
      final expenses =
          ref
              .watch(
                monthExpensesProvider(
                  MonthRoomKey(roomId: key.roomId, month: key.month),
                ),
              )
              .valueOrNull ??
          [];

      final bills =
          ref
              .watch(
                billsStreamProvider(
                  MonthBillKey(roomId: key.roomId, month: key.month),
                ),
              )
              .valueOrNull ??
          [];

      final room = ref.watch(roomStreamProvider(key.roomId)).valueOrNull;
      final memberIds = room?.historicalMemberIds ?? [];

      return ref
          .watch(balanceServiceProvider)
          .computeNetBalances(
            expenses: expenses,
            bills: bills,
            memberIds: memberIds,
            legacyBillMemberIds: room?.billFallbackMemberIds,
            settlements:
                (ref.watch(settlementsStreamProvider(key.roomId)).valueOrNull ??
                        [])
                    .where((s) => s.effectiveMonth == key.month)
                    .toList(),
          );
    });

/// Current user balance for a room in a specific month.
final monthUserBalanceProvider = Provider.family<double, MonthBalanceKey>((
  ref,
  key,
) {
  final balances = ref.watch(monthNetBalancesProvider(key));
  final userId = ref.watch(currentUserIdProvider);
  return balances[userId] ?? 0;
});

final simplifiedDebtsProvider = Provider.family<List<Debt>, String>((
  ref,
  roomId,
) {
  final balances = ref.watch(netBalancesProvider(roomId));
  return ref.watch(balanceServiceProvider).simplifyDebts(balances);
});

final monthSimplifiedDebtsProvider =
    Provider.family<List<Debt>, MonthBalanceKey>((ref, key) {
      final balances = ref.watch(monthNetBalancesProvider(key));
      return ref.watch(balanceServiceProvider).simplifyDebts(balances);
    });

final currentUserBalanceProvider = Provider.family<double, String>((
  ref,
  roomId,
) {
  final balances = ref.watch(netBalancesProvider(roomId));
  final userId = ref.watch(currentUserIdProvider);
  return balances[userId] ?? 0;
});

final currentUserDebtsProvider = Provider.family<List<Debt>, String>((
  ref,
  roomId,
) {
  final debts = ref.watch(
    monthPairDebtsProvider(
      MonthBalanceKey(roomId: roomId, month: ref.watch(currentMonthProvider)),
    ),
  );
  final userId = ref.watch(currentUserIdProvider);
  return debts.where((d) => d.from == userId || d.to == userId).toList();
});

final monthCurrentUserDebtsProvider =
    Provider.family<List<Debt>, MonthBalanceKey>((ref, key) {
      final debts = ref.watch(monthPairDebtsProvider(key));
      final userId = ref.watch(currentUserIdProvider);
      return debts.where((d) => d.from == userId || d.to == userId).toList();
    });

final monthPairDebtsProvider = Provider.family<List<Debt>, MonthBalanceKey>((
  ref,
  key,
) {
  final room = ref.watch(roomStreamProvider(key.roomId)).valueOrNull;
  return ref
      .watch(balanceServiceProvider)
      .pairDebts(
        memberIds: room?.historicalMemberIds ?? [],
        legacyBillMemberIds: room?.billFallbackMemberIds,
        expenses:
            ref
                .watch(
                  monthExpensesProvider(
                    MonthRoomKey(roomId: key.roomId, month: key.month),
                  ),
                )
                .valueOrNull ??
            [],
        bills:
            ref
                .watch(
                  billsStreamProvider(
                    MonthBillKey(roomId: key.roomId, month: key.month),
                  ),
                )
                .valueOrNull ??
            [],
        settlements:
            (ref.watch(settlementsStreamProvider(key.roomId)).valueOrNull ?? [])
                .where((s) => s.effectiveMonth == key.month)
                .toList(),
      );
});

/// Overall balance across all rooms (current month).
final overallBalanceProvider = Provider<double>((ref) {
  final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
  double total = 0;
  for (final room in rooms) {
    total += ref.watch(currentUserBalanceProvider(room.id));
  }
  return total;
});

/// Overall balance across all rooms for a specific month.
final monthOverallBalanceProvider = Provider.family<double, String>((
  ref,
  month,
) {
  final rooms = ref.watch(userRoomsProvider).valueOrNull ?? [];
  double total = 0;
  for (final room in rooms) {
    total += ref.watch(
      monthUserBalanceProvider(MonthBalanceKey(roomId: room.id, month: month)),
    );
  }
  return total;
});

final detailedDebtsMapProvider =
    Provider.family<
      Map<String, Map<String, List<DebtTransaction>>>,
      MonthBalanceKey
    >((ref, key) {
      final expenses =
          ref
              .watch(
                monthExpensesProvider(
                  MonthRoomKey(roomId: key.roomId, month: key.month),
                ),
              )
              .valueOrNull ??
          [];

      final bills =
          ref
              .watch(
                billsStreamProvider(
                  MonthBillKey(roomId: key.roomId, month: key.month),
                ),
              )
              .valueOrNull ??
          [];

      final room = ref.watch(roomStreamProvider(key.roomId)).valueOrNull;
      final memberIds = room?.billFallbackMemberIds ?? [];

      final debtMap = <String, Map<String, List<DebtTransaction>>>{};

      // Process expenses
      for (final expense in expenses) {
        final payer = expense.paidBy;
        final splitAmong = expense.splitAmong;
        if (splitAmong.isEmpty) continue;
        final share = expense.amount / splitAmong.length;

        for (final member in splitAmong) {
          if (member == payer) continue;
          debtMap.putIfAbsent(member, () => {});
          debtMap[member]!.putIfAbsent(payer, () => []);
          debtMap[member]![payer]!.add(
            DebtTransaction(
              id: expense.id,
              title: expense.title,
              date: expense.date,
              totalAmount: expense.amount,
              userShare: share,
              paidBy: payer,
              splitAmong: splitAmong,
              splitType: expense.splitType,
              isBill: false,
            ),
          );
        }
      }

      // Process bills (always equal split among all members)
      for (final bill in bills) {
        final payer = bill.paidBy;
        final participants = bill.splitAmong.isEmpty
            ? memberIds
            : bill.splitAmong;
        if (participants.isEmpty) continue;
        final share = bill.amount / participants.length;

        for (final member in participants) {
          if (member == payer) continue;
          debtMap.putIfAbsent(member, () => {});
          debtMap[member]!.putIfAbsent(payer, () => []);
          debtMap[member]![payer]!.add(
            DebtTransaction(
              id: bill.id,
              title: bill.typeName,
              date: bill.date,
              totalAmount: bill.amount,
              userShare: share,
              paidBy: payer,
              splitAmong: participants,
              splitType: SplitType.equal,
              isBill: true,
            ),
          );
        }
      }

      return debtMap;
    });

/// Include recorded participants when reading older rooms that predate the
/// durable participant list. Active membership is used only for new entries.
final monthParticipantIdsProvider =
    Provider.family<List<String>, MonthBalanceKey>((ref, key) {
      final room = ref.watch(roomStreamProvider(key.roomId)).valueOrNull;
      final expenses =
          ref
              .watch(
                monthExpensesProvider(
                  MonthRoomKey(roomId: key.roomId, month: key.month),
                ),
              )
              .valueOrNull ??
          [];
      final bills =
          ref
              .watch(
                billsStreamProvider(
                  MonthBillKey(roomId: key.roomId, month: key.month),
                ),
              )
              .valueOrNull ??
          [];
      final settlements =
          ref.watch(settlementsStreamProvider(key.roomId)).valueOrNull ?? [];
      return {
        for (final e in expenses) ...[e.paidBy, ...e.splitAmong],
        for (final b in bills) ...[
          b.paidBy,
          ...(b.splitAmong.isEmpty
              ? (room?.billFallbackMemberIds ?? <String>[])
              : b.splitAmong),
        ],
        for (final s in settlements.where(
          (s) => s.effectiveMonth == key.month,
        )) ...[s.fromUserId, s.toUserId],
      }.toList()..sort();
    });
