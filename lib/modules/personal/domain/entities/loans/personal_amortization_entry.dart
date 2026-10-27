class PersonalAmortizationEntry {
  final int month;
  final DateTime dueDate;
  final double emi;
  final double principal;
  final double interest;
  final double remainingPrincipal;
  final bool isPaid;

  const PersonalAmortizationEntry({
    required this.month,
    required this.dueDate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.remainingPrincipal,
    required this.isPaid,
  });
}
