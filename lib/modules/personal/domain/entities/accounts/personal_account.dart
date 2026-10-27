enum PersonalAccountType { cash, bank, creditCard }

class PersonalAccount {
  final String id;
  final String name;
  final PersonalAccountType type;

  /// Signed opening balance: an outstanding credit-card debt is negative.
  final double openingBalance;
  final String? last4;
  final bool archived;

  const PersonalAccount({
    required this.id,
    required this.name,
    required this.type,
    this.openingBalance = 0,
    this.last4,
    this.archived = false,
  });

  String get typeLabel => switch (type) {
    PersonalAccountType.cash => 'Cash',
    PersonalAccountType.bank => 'Bank account',
    PersonalAccountType.creditCard => 'Credit card',
  };
}
