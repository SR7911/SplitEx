/// Other people's shares of an expense paid by the account owner.
/// The owner's share is the unallocated remainder.
class ExpenseSplitShare {
  final String personName;
  final double amount;
  final String? debtId;

  const ExpenseSplitShare({
    required this.personName,
    required this.amount,
    this.debtId,
  });
}

enum ExpenseSplitMode { equal, manual }

class ExpenseSplit {
  final ExpenseSplitMode mode;
  final List<ExpenseSplitShare> shares;

  const ExpenseSplit({required this.mode, required this.shares});

  int ownShareCents(double total) =>
      roundedMoneyCents(total) -
      shares.fold<int>(
        0,
        (sum, share) => sum + roundedMoneyCents(share.amount),
      );

  void validate(double total) {
    final totalCents = moneyCents(total);
    if (totalCents <= 0) throw StateError('Enter a valid expense amount.');
    if (shares.isEmpty)
      throw StateError('Add at least one person to split with.');
    if (shares.length > 100) {
      throw StateError('Use at most 100 people in one expense split.');
    }
    final names = <String>{};
    var allocated = 0;
    for (final share in shares) {
      final name = share.personName.trim();
      if (name.isEmpty) throw StateError('Enter every person’s name.');
      if (!names.add(name.toLowerCase())) {
        throw StateError('Each person can appear only once.');
      }
      final cents = moneyCents(share.amount);
      if (cents <= 0)
        throw StateError('Each person’s share must be above zero.');
      allocated += cents;
      if (allocated > totalCents) {
        throw StateError('People’s shares cannot exceed the expense total.');
      }
    }
  }
}

/// Read-side currency conversion for stored/calculated values with extra precision.
/// This does not change persisted values or relax new-entry validation.
int roundedMoneyCents(double amount) {
  if (!amount.isFinite || amount < 0 || amount * 100 > 9007199254740991) {
    throw StateError('Enter a valid amount.');
  }
  return (amount * 100).round();
}

/// Validate user-entered money before saving, then allocate it in paise.
int moneyCents(double amount) {
  final cents = roundedMoneyCents(amount);
  if ((amount * 100 - cents).abs() > 0.000001) {
    throw StateError('Use at most two decimal places.');
  }
  return cents;
}

ExpenseSplit equalExpenseSplit(double total, List<String> people) {
  final cents = moneyCents(total);
  if (people.isEmpty || cents <= people.length) {
    throw StateError('The expense is too small for this equal split.');
  }
  final each = cents ~/ (people.length + 1);
  if (each <= 0) throw StateError('Each share must be above zero.');
  return ExpenseSplit(
    mode: ExpenseSplitMode.equal,
    shares: [
      for (final person in people)
        ExpenseSplitShare(personName: person.trim(), amount: each / 100),
    ],
  );
}
