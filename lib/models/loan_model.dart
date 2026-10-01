import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanStatus { active, settled, foreclosed }

enum LoanType { borrowed, lent }

class LoanModel {
  final String id;
  final String userId;
  final String title; // e.g. "HDFC Home Loan"
  final LoanType loanType; // borrowed = I owe, lent = someone owes me
  final double principal;
  final double annualInterestRate; // 0 for interest-free
  final int tenureMonths;
  final DateTime startDate;
  final int emiDueDay; // 1–28
  final LoanStatus status;
  final String? lenderBorrowerName; // person/bank name
  final String? notes;
  final String? recurringId; // linked personal_recurring doc id
  final DateTime createdAt;
  final double? customEmi; // user-overridden EMI amount

  // ── One-time charges (deducted from disbursal, not part of EMI) ──────────
  final double processingFee;   // flat or % of principal
  final double insuranceFee;    // loan protection insurance
  final double otherCharges;    // stamp duty, legal, etc.
  final double gstOnFees;       // 18% GST on processingFee (auto-calculated)

  const LoanModel({
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
    this.lenderBorrowerName,
    this.notes,
    this.recurringId,
    required this.createdAt,
    this.customEmi,
    this.processingFee = 0,
    this.insuranceFee = 0,
    this.otherCharges = 0,
    this.gstOnFees = 0,
  });

  // ── Derived ──────────────────────────────────────────────────────────────

  DateTime get endDate {
    final m = startDate.month + tenureMonths;
    final y = startDate.year + (m - 1) ~/ 12;
    final mo = ((m - 1) % 12) + 1;
    return DateTime(y, mo, startDate.day);
  }

  /// Net amount actually received after all upfront deductions.
  double get netDisbursed => principal - processingFee - insuranceFee - otherCharges - gstOnFees;

  /// Total one-time charges.
  double get totalCharges => processingFee + insuranceFee + otherCharges + gstOnFees;

  /// Standard EMI using reducing-balance formula.
  /// For 0% interest, EMI = principal / tenure.
  double get baseEmi {
    if (customEmi != null && customEmi! > 0) return customEmi!;
    if (annualInterestRate == 0) return principal / tenureMonths;
    final r = annualInterestRate / (12 * 100);
    final n = tenureMonths;
    return principal * r * _pow(1 + r, n) / (_pow(1 + r, n) - 1);
  }

  static double _pow(double base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  factory LoanModel.fromMap(Map<String, dynamic> map, String id) {
    return LoanModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      loanType: LoanType.values.firstWhere(
        (e) => e.name == map['loanType'],
        orElse: () => LoanType.borrowed,
      ),
      principal: (map['principal'] ?? 0).toDouble(),
      annualInterestRate: (map['annualInterestRate'] ?? 0).toDouble(),
      tenureMonths: map['tenureMonths'] ?? 1,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      emiDueDay: map['emiDueDay'] ?? 1,
      status: LoanStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LoanStatus.active,
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
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'loanType': loanType.name,
        'principal': principal,
        'annualInterestRate': annualInterestRate,
        'tenureMonths': tenureMonths,
        'startDate': Timestamp.fromDate(startDate),
        'emiDueDay': emiDueDay,
        'status': status.name,
        if (lenderBorrowerName != null) 'lenderBorrowerName': lenderBorrowerName,
        if (notes != null) 'notes': notes,
        if (recurringId != null) 'recurringId': recurringId,
        'createdAt': FieldValue.serverTimestamp(),
        if (customEmi != null && customEmi! > 0) 'customEmi': customEmi,
        if (processingFee > 0) 'processingFee': processingFee,
        if (insuranceFee > 0) 'insuranceFee': insuranceFee,
        if (otherCharges > 0) 'otherCharges': otherCharges,
        if (gstOnFees > 0) 'gstOnFees': gstOnFees,
      };

  LoanModel copyWith({
    LoanStatus? status,
    String? recurringId,
    double? principal,
    double? annualInterestRate,
    int? tenureMonths,
    int? emiDueDay,
    String? notes,
    double? customEmi,
    double? processingFee,
    double? insuranceFee,
    double? otherCharges,
    double? gstOnFees,
  }) =>
      LoanModel(
        id: id,
        userId: userId,
        title: title,
        loanType: loanType,
        principal: principal ?? this.principal,
        annualInterestRate: annualInterestRate ?? this.annualInterestRate,
        tenureMonths: tenureMonths ?? this.tenureMonths,
        startDate: startDate,
        emiDueDay: emiDueDay ?? this.emiDueDay,
        status: status ?? this.status,
        lenderBorrowerName: lenderBorrowerName,
        notes: notes ?? this.notes,
        recurringId: recurringId ?? this.recurringId,
        createdAt: createdAt,
        customEmi: customEmi ?? this.customEmi,
        processingFee: processingFee ?? this.processingFee,
        insuranceFee: insuranceFee ?? this.insuranceFee,
        otherCharges: otherCharges ?? this.otherCharges,
        gstOnFees: gstOnFees ?? this.gstOnFees,
      );
}

// ── Payment log entry ──────────────────────────────────────────────────────

enum PaymentType { emi, partial, foreclosure }

class LoanPaymentModel {
  final String id;
  final double amount;
  final double principalComponent;
  final double interestComponent;
  final double remainingPrincipalAfter;
  final DateTime date;
  final PaymentType type;
  final String? note;

  const LoanPaymentModel({
    required this.id,
    required this.amount,
    required this.principalComponent,
    required this.interestComponent,
    required this.remainingPrincipalAfter,
    required this.date,
    required this.type,
    this.note,
  });

  factory LoanPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return LoanPaymentModel(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      principalComponent: (map['principalComponent'] ?? 0).toDouble(),
      interestComponent: (map['interestComponent'] ?? 0).toDouble(),
      remainingPrincipalAfter: (map['remainingPrincipalAfter'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: PaymentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PaymentType.emi,
      ),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'principalComponent': principalComponent,
        'interestComponent': interestComponent,
        'remainingPrincipalAfter': remainingPrincipalAfter,
        'date': Timestamp.fromDate(date),
        'type': type.name,
        if (note != null) 'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

// ── Amortization schedule entry (computed, not stored) ────────────────────

class AmortizationEntry {
  final int month; // 1-based
  final DateTime dueDate;
  final double emi;
  final double principal;
  final double interest;
  final double remainingPrincipal;
  final bool isPaid;

  const AmortizationEntry({
    required this.month,
    required this.dueDate,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.remainingPrincipal,
    required this.isPaid,
  });
}
