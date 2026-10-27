enum DebtSettlementAction { full, partial, writeOff }

class DebtSettlementCommand {
  final DebtSettlementAction action;
  final DateTime? date;
  final double? amount;
  final String? note;

  const DebtSettlementCommand({
    required this.action,
    this.date,
    this.amount,
    this.note,
  });
}
