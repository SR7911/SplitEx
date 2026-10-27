class PersonalLoanChanges {
  final double? principal;
  final double? annualInterestRate;
  final int? tenureMonths;
  final int? emiDueDay;
  final String? notes;
  final double? customEmi;
  final double? processingFee;
  final double? insuranceFee;
  final double? otherCharges;
  final double? gstOnFees;

  const PersonalLoanChanges({
    this.principal,
    this.annualInterestRate,
    this.tenureMonths,
    this.emiDueDay,
    this.notes,
    this.customEmi,
    this.processingFee,
    this.insuranceFee,
    this.otherCharges,
    this.gstOnFees,
  });
}
