import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/entities/loans/personal_loan.dart';
import '../../../domain/entities/loans/personal_loan_payment.dart';

class PersonalLoanFirestoreMapper {
  static Map<String, dynamic> loanToMap(PersonalLoan loan) => {
    'userId': loan.userId,
    'title': loan.title,
    'loanType': loan.loanType.name,
    'principal': loan.principal,
    'annualInterestRate': loan.annualInterestRate,
    'tenureMonths': loan.tenureMonths,
    'startDate': Timestamp.fromDate(loan.startDate),
    'emiDueDay': loan.emiDueDay,
    'status': loan.status.name,
    if (loan.lenderBorrowerName != null)
      'lenderBorrowerName': loan.lenderBorrowerName,
    if (loan.notes != null) 'notes': loan.notes,
    if (loan.recurringId != null) 'recurringId': loan.recurringId,
    'createdAt': FieldValue.serverTimestamp(),
    if (loan.customEmi != null && loan.customEmi! > 0)
      'customEmi': loan.customEmi,
    if (loan.processingFee > 0) 'processingFee': loan.processingFee,
    if (loan.insuranceFee > 0) 'insuranceFee': loan.insuranceFee,
    if (loan.otherCharges > 0) 'otherCharges': loan.otherCharges,
    if (loan.gstOnFees > 0) 'gstOnFees': loan.gstOnFees,
    if (loan.emiStartDate != null)
      'emiStartDate': Timestamp.fromDate(loan.emiStartDate!),
  };

  static PersonalLoan loanFromMap(Map<String, dynamic> map, String id) =>
      PersonalLoan(
        id: id,
        userId: map['userId'] ?? '',
        title: map['title'] ?? '',
        loanType: PersonalLoanType.values.firstWhere(
          (value) => value.name == map['loanType'],
          orElse: () => PersonalLoanType.borrowed,
        ),
        principal: (map['principal'] ?? 0).toDouble(),
        annualInterestRate: (map['annualInterestRate'] ?? 0).toDouble(),
        tenureMonths: map['tenureMonths'] ?? 1,
        startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        emiDueDay: map['emiDueDay'] ?? 1,
        status: PersonalLoanStatus.values.firstWhere(
          (value) => value.name == map['status'],
          orElse: () => PersonalLoanStatus.active,
        ),
        lenderBorrowerName: map['lenderBorrowerName'],
        notes: map['notes'],
        recurringId: map['recurringId'],
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        customEmi: (map['customEmi'] as num?)?.toDouble(),
        processingFee: (map['processingFee'] ?? 0).toDouble(),
        insuranceFee: (map['insuranceFee'] ?? 0).toDouble(),
        otherCharges: (map['otherCharges'] ?? 0).toDouble(),
        gstOnFees: (map['gstOnFees'] ?? 0).toDouble(),
        emiStartDate: (map['emiStartDate'] as Timestamp?)?.toDate(),
      );

  static PersonalLoanPayment paymentFromMap(
    Map<String, dynamic> map,
    String id,
  ) => PersonalLoanPayment(
    id: id,
    amount: (map['amount'] ?? 0).toDouble(),
    principalComponent: (map['principalComponent'] ?? 0).toDouble(),
    interestComponent: (map['interestComponent'] ?? 0).toDouble(),
    remainingPrincipalAfter: (map['remainingPrincipalAfter'] ?? 0).toDouble(),
    date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    type: PersonalLoanPaymentType.values.firstWhere(
      (value) => value.name == map['type'],
      orElse: () => PersonalLoanPaymentType.emi,
    ),
    note: map['note'],
  );

  static Map<String, dynamic> paymentToMap(PersonalLoanPayment payment) => {
    'amount': payment.amount,
    'principalComponent': payment.principalComponent,
    'interestComponent': payment.interestComponent,
    'remainingPrincipalAfter': payment.remainingPrincipalAfter,
    'date': Timestamp.fromDate(payment.date),
    'type': payment.type.name,
    if (payment.note != null) 'note': payment.note,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
