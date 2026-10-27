class PersonalLoanEmiProgress {
  final int paidCount;
  final int totalCount;
  final DateTime? nextDueDate;

  const PersonalLoanEmiProgress({
    required this.paidCount,
    required this.totalCount,
    this.nextDueDate,
  });
}

class PersonalLoanSummary {
  final double totalOutstanding;
  final double totalMonthlyEmi;
  final int activeCount;

  const PersonalLoanSummary({
    required this.totalOutstanding,
    required this.totalMonthlyEmi,
    required this.activeCount,
  });
}
