enum PersonalLoanPaymentType { emi, partial, foreclosure }

class PersonalLoanPayment {
  final String id;
  final double amount;
  final double principalComponent;
  final double interestComponent;
  final double remainingPrincipalAfter;
  final DateTime date;
  final PersonalLoanPaymentType type;
  final String? note;

  const PersonalLoanPayment({
    required this.id,
    required this.amount,
    required this.principalComponent,
    required this.interestComponent,
    required this.remainingPrincipalAfter,
    required this.date,
    required this.type,
    this.note,
  });
}
