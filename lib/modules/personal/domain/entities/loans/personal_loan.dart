enum PersonalLoanStatus { active, settled, foreclosed }

enum PersonalLoanType { borrowed, lent }

class PersonalLoan {
  final String id;
  final String userId;
  final String title;
  final PersonalLoanType loanType;
  final double principal;
  final double annualInterestRate;
  final int tenureMonths;
  final DateTime startDate;
  final int emiDueDay;
  final PersonalLoanStatus status;
  final String? lenderBorrowerName;
  final String? notes;
  final String? recurringId;
  final DateTime createdAt;
  final double? customEmi;
  final DateTime? emiStartDate;
  final double processingFee;
  final double insuranceFee;
  final double otherCharges;
  final double gstOnFees;

  const PersonalLoan({
    required this.id,
    required this.userId,
    required this.title,
    required this.loanType,
    required this.principal,
    required this.annualInterestRate,
    required this.tenureMonths,
    required this.startDate,
    required this.emiDueDay,
    required this.status,
    required this.createdAt,
    this.lenderBorrowerName,
    this.notes,
    this.recurringId,
    this.customEmi,
    this.emiStartDate,
    this.processingFee = 0,
    this.insuranceFee = 0,
    this.otherCharges = 0,
    this.gstOnFees = 0,
  });

  DateTime get effectiveEmiStart =>
      emiStartDate ?? DateTime(startDate.year, startDate.month + 1, emiDueDay);

  DateTime get endDate {
    final reference = effectiveEmiStart;
    final month = reference.month + tenureMonths - 1;
    final year = reference.year + month ~/ 12;
    final calendarMonth = month % 12 == 0 ? 12 : month % 12;
    final maxDay = DateTime(year, calendarMonth + 1, 0).day;
    return DateTime(year, calendarMonth, emiDueDay.clamp(1, maxDay));
  }

  double get totalCharges =>
      processingFee + insuranceFee + otherCharges + gstOnFees;

  double get netDisbursed => principal - totalCharges;

  double get baseEmi {
    return calculatePersonalLoanEmi(
      principal,
      annualInterestRate,
      tenureMonths,
      customEmi: customEmi,
    );
  }
}

double calculatePersonalLoanEmi(
  double principal,
  double annualInterestRate,
  int tenureMonths, {
  double? customEmi,
}) {
  if (customEmi != null && customEmi > 0) return customEmi;
  if (annualInterestRate == 0) return principal / tenureMonths;
  final rate = annualInterestRate / (12 * 100);
  var factor = 1.0;
  for (var month = 0; month < tenureMonths; month++) {
    factor *= 1 + rate;
  }
  return principal * rate * factor / (factor - 1);
}
