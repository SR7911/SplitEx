class SavingsGoal {
  final String id, title;
  final int targetMinor, savedMinor;
  final DateTime? targetDate;
  final String? accountId;
  final bool archived;
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetMinor,
    this.savedMinor = 0,
    this.targetDate,
    this.accountId,
    this.archived = false,
  });
  double get target => targetMinor / 100;
  double get saved => savedMinor / 100;
  double get remaining =>
      (targetMinor - savedMinor).clamp(0, targetMinor) / 100;
  double get progress =>
      targetMinor > 0 ? (savedMinor / targetMinor).clamp(0, 1) : 0;
  bool get reached => savedMinor >= targetMinor;
}

class SavingsEntry {
  final String id;
  final int amountMinor;
  final DateTime date;
  final String note;
  const SavingsEntry({
    required this.id,
    required this.amountMinor,
    required this.date,
    this.note = '',
  });
}
