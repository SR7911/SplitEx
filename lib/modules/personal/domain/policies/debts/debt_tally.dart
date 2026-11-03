import '../../entities/transactions/expense_split.dart';
import '../../entities/transactions/personal_transaction.dart';

String debtPersonKey(String name) => name.trim().toLowerCase();

/// The settled flag is authoritative for closed/legacy debts even when their
/// older repayment totals are incomplete. Only outstanding debts may be offset.
bool isActiveTallyDebt(PersonalTransaction debt) =>
    debt.hasDebt && !debt.isSettled && roundedMoneyCents(debt.remainingAmount) > 0;

class DebtTallyPlan {
  final String personName;
  final int lentCents;
  final int borrowedCents;
  final Map<String, int> offsetsCents;

  const DebtTallyPlan({
    required this.personName,
    required this.lentCents,
    required this.borrowedCents,
    required this.offsetsCents,
  });

  int get offsetCents => lentCents < borrowedCents ? lentCents : borrowedCents;
  int get netCents => lentCents - borrowedCents;
  bool get canTally => offsetCents > 0;
}

DebtTallyPlan planDebtTally(
  String personName,
  List<PersonalTransaction> debts,
) {
  final key = debtPersonKey(personName);
  final eligible =
      debts
          .where(
            (debt) =>
                debtPersonKey(debt.personName ?? '') == key &&
                isActiveTallyDebt(debt),
          )
          .toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate == 0 ? a.id.compareTo(b.id) : byDate;
        });
  final lent = eligible
      .where((debt) => debt.debtType == DebtType.lent)
      .toList();
  final borrowed = eligible
      .where((debt) => debt.debtType == DebtType.borrowed)
      .toList();
  final lentCents = lent.fold<int>(
    0,
    (sum, debt) => sum + roundedMoneyCents(debt.remainingAmount),
  );
  final borrowedCents = borrowed.fold<int>(
    0,
    (sum, debt) => sum + roundedMoneyCents(debt.remainingAmount),
  );
  var remaining = lentCents < borrowedCents ? lentCents : borrowedCents;
  final offsets = <String, int>{};
  for (final side in [lent, borrowed]) {
    var sideRemaining = remaining;
    for (final debt in side) {
      if (sideRemaining == 0) break;
      final available = roundedMoneyCents(debt.remainingAmount);
      final used = available < sideRemaining ? available : sideRemaining;
      offsets[debt.id] = used;
      sideRemaining -= used;
    }
  }
  return DebtTallyPlan(
    personName: personName.trim(),
    lentCents: lentCents,
    borrowedCents: borrowedCents,
    offsetsCents: offsets,
  );
}
