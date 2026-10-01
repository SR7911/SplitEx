import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/models/personal_transaction_model.dart';
import 'package:split_ex/services/personal_expense_service.dart';
import 'package:split_ex/services/usage_tracker.dart';

class LoanService {
  final _firestore = FirebaseFirestore.instance;
  final _tracker = UsageTracker.instance;
  final _personalService = PersonalExpenseService();

  // ── Collections ───────────────────────────────────────────────────────────

  CollectionReference _loanCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('loans');

  CollectionReference _paymentCol(String userId, String loanId) =>
      _loanCol(userId).doc(loanId).collection('payments');

  // ── Loans CRUD ────────────────────────────────────────────────────────────

  Stream<List<LoanModel>> getLoansStream(String userId) {
    return _loanCol(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map((d) => LoanModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    });
  }

  /// Adds a loan. Does NOT auto-create a recurring entry.
  Future<String> addLoan(String userId, LoanModel loan) async {
    final ref = await _loanCol(userId).add(loan.toMap());
    await _tracker.trackWrites(1);
    return ref.id;
  }

  /// Updates principal/rate/tenure — recalculates base EMI and updates recurring amount.
  Future<void> updateLoan(String userId, String loanId, {
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
  }) async {
    final doc = await _loanCol(userId).doc(loanId).get();
    _tracker.trackReads(1);
    final loan = LoanModel.fromMap(doc.data() as Map<String, dynamic>, loanId);

    final updated = loan.copyWith(
      principal: principal,
      annualInterestRate: annualInterestRate,
      tenureMonths: tenureMonths,
      emiDueDay: emiDueDay,
      notes: notes,
      processingFee: processingFee,
      insuranceFee: insuranceFee,
      otherCharges: otherCharges,
      gstOnFees: gstOnFees,
    );

    final updateMap = <String, dynamic>{};
    if (principal != null) updateMap['principal'] = principal;
    if (annualInterestRate != null) updateMap['annualInterestRate'] = annualInterestRate;
    if (tenureMonths != null) updateMap['tenureMonths'] = tenureMonths;
    if (emiDueDay != null) updateMap['emiDueDay'] = emiDueDay;
    if (notes != null) updateMap['notes'] = notes;
    if (customEmi != null) updateMap['customEmi'] = customEmi == 0 ? FieldValue.delete() : customEmi;
    if (processingFee != null) updateMap['processingFee'] = processingFee;
    if (insuranceFee != null) updateMap['insuranceFee'] = insuranceFee;
    if (otherCharges != null) updateMap['otherCharges'] = otherCharges;
    if (gstOnFees != null) updateMap['gstOnFees'] = gstOnFees;

    await _loanCol(userId).doc(loanId).update(updateMap);
    await _tracker.trackWrites(1);

    // Sync recurring amount if linked
    if (loan.recurringId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_recurring')
          .doc(loan.recurringId)
          .update({
        'amount': updated.baseEmi,
        if (emiDueDay != null) 'dayOfMonth': emiDueDay,
      });
      await _tracker.trackWrites(1);
    }
  }

  /// Deletes a loan and all its payment sub-documents.
  Future<void> deleteLoan(String userId, String loanId) async {
    final payments = await _paymentCol(userId, loanId).get();
    for (final doc in payments.docs) {
      await doc.reference.delete();
    }
    await _loanCol(userId).doc(loanId).delete();
    await _tracker.trackWrites(1);
  }

  /// Deletes a recurring entry by id.
  Future<void> deleteRecurring(String userId, String recurringId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_recurring')
        .doc(recurringId)
        .delete();
    await _tracker.trackWrites(1);
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Stream<List<LoanPaymentModel>> getPaymentsStream(String userId, String loanId) {
    return _paymentCol(userId, loanId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      _tracker.trackReads(snap.docs.length);
      return snap.docs
          .map((d) => LoanPaymentModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    });
  }

  /// Logs a regular EMI payment. Computes interest/principal split from remaining principal.
  Future<void> logEmiPayment(String userId, String loanId, double remainingPrincipal, DateTime paymentDate) async {
    final doc = await _loanCol(userId).doc(loanId).get();
    _tracker.trackReads(1);
    final loan = LoanModel.fromMap(doc.data() as Map<String, dynamic>, loanId);

    final monthlyRate = loan.annualInterestRate / (12 * 100);
    final interest = remainingPrincipal * monthlyRate;
    final emi = loan.baseEmi;
    final principalPaid = emi - interest;
    final newRemaining = (remainingPrincipal - principalPaid).clamp(0.0, double.infinity);

    final payment = LoanPaymentModel(
      id: '',
      amount: emi,
      principalComponent: principalPaid,
      interestComponent: interest,
      remainingPrincipalAfter: newRemaining,
      date: paymentDate,
      type: PaymentType.emi,
    );

    await _paymentCol(userId, loanId).add(payment.toMap());
    await _tracker.trackWrites(1);

    // Auto-add as personal expense transaction
    await _addPersonalExpenseForPayment(userId, loan, emi, paymentDate, 'EMI');

    // If fully paid, mark settled
    if (newRemaining < 1.0) {
      await _closeLoan(userId, loanId, loan, LoanStatus.settled);
    }
  }

  /// Logs a partial/lump-sum payment. Reduces principal; keeps end date fixed (lowers future EMI).
  Future<void> logPartialPayment(
    String userId,
    String loanId,
    double remainingPrincipal,
    double partialAmount,
    DateTime paymentDate, {
    String? note,
  }) async {
    final doc = await _loanCol(userId).doc(loanId).get();
    _tracker.trackReads(1);
    final loan = LoanModel.fromMap(doc.data() as Map<String, dynamic>, loanId);

    final monthlyRate = loan.annualInterestRate / (12 * 100);
    final interest = (remainingPrincipal * monthlyRate).clamp(0.0, partialAmount);
    final principalPaid = (partialAmount - interest).clamp(0.0, remainingPrincipal);
    final newRemaining = (remainingPrincipal - principalPaid).clamp(0.0, double.infinity);

    final payment = LoanPaymentModel(
      id: '',
      amount: partialAmount,
      principalComponent: principalPaid,
      interestComponent: interest,
      remainingPrincipalAfter: newRemaining,
      date: paymentDate,
      type: PaymentType.partial,
      note: note,
    );

    await _paymentCol(userId, loanId).add(payment.toMap());
    await _tracker.trackWrites(1);

    await _addPersonalExpenseForPayment(userId, loan, partialAmount, paymentDate, 'Partial Payment');

    // Recalculate new EMI based on remaining principal and remaining months, update recurring
    if (loan.recurringId != null && newRemaining > 1.0) {
      final monthsPaid = await _countPayments(userId, loanId);
      final remainingMonths = (loan.tenureMonths - monthsPaid).clamp(1, loan.tenureMonths);
      final newEmi = _calcEmi(newRemaining, loan.annualInterestRate, remainingMonths);
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_recurring')
          .doc(loan.recurringId)
          .update({'amount': newEmi});
      await _tracker.trackWrites(1);
    }

    if (newRemaining < 1.0) {
      await _closeLoan(userId, loanId, loan, LoanStatus.settled);
    }
  }

  /// Force-closes the loan (foreclosure). Pays off remaining principal + accrued interest.
  Future<void> forecloseLoan(String userId, String loanId, double remainingPrincipal) async {
    final doc = await _loanCol(userId).doc(loanId).get();
    _tracker.trackReads(1);
    final loan = LoanModel.fromMap(doc.data() as Map<String, dynamic>, loanId);

    final now = DateTime.now();
    final monthlyRate = loan.annualInterestRate / (12 * 100);
    final accruedInterest = remainingPrincipal * monthlyRate;
    final totalPayoff = remainingPrincipal + accruedInterest;

    final payment = LoanPaymentModel(
      id: '',
      amount: totalPayoff,
      principalComponent: remainingPrincipal,
      interestComponent: accruedInterest,
      remainingPrincipalAfter: 0,
      date: now,
      type: PaymentType.foreclosure,
      note: 'Foreclosure / Force Close',
    );

    await _paymentCol(userId, loanId).add(payment.toMap());
    await _tracker.trackWrites(1);

    await _addPersonalExpenseForPayment(userId, loan, totalPayoff, now, 'Foreclosure');
    await _closeLoan(userId, loanId, loan, LoanStatus.foreclosed);
  }

  // ── Missed EMI detection & bulk logging ─────────────────────────────────────

  /// Returns the list of due dates that have no corresponding EMI payment logged.
  /// Only considers EMI-type payments; partial/foreclosure are ignored.
  List<DateTime> getMissedEmiDates(LoanModel loan, List<LoanPaymentModel> payments) {
    if (loan.status != LoanStatus.active) return [];
    final now = DateTime.now();
    final emiPayments = payments.where((p) => p.type == PaymentType.emi).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final missed = <DateTime>[];
    for (int i = 1; i <= loan.tenureMonths; i++) {
      final due = _nthEmiDate(loan, i);
      if (due.isAfter(now)) break;
      // Check if an EMI payment exists within ±15 days of this due date
      final hasPaid = emiPayments.any((p) => p.date.difference(due).inDays.abs() <= 15);
      if (!hasPaid) missed.add(due);
    }
    return missed;
  }

  /// Logs all missed EMIs sequentially, each reducing the running principal.
  Future<void> logMissedEmis(
    String userId,
    String loanId,
    List<DateTime> missedDates,
  ) async {
    final doc = await _loanCol(userId).doc(loanId).get();
    _tracker.trackReads(1);
    final loan = LoanModel.fromMap(doc.data() as Map<String, dynamic>, loanId);

    // Get current remaining principal
    final paymentsSnap = await _paymentCol(userId, loanId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    _tracker.trackReads(1);

    double remaining = loan.principal;
    if (paymentsSnap.docs.isNotEmpty) {
      remaining = (paymentsSnap.docs.first['remainingPrincipalAfter'] as num?)?.toDouble() ?? remaining;
    }

    final monthlyRate = loan.annualInterestRate / (12 * 100);
    for (final dueDate in missedDates) {
      if (remaining < 1.0) break;
      final interest = remaining * monthlyRate;
      final emi = loan.baseEmi;
      final principalPaid = (emi - interest).clamp(0.0, remaining);
      remaining = (remaining - principalPaid).clamp(0.0, double.infinity);

      final payment = LoanPaymentModel(
        id: '',
        amount: emi,
        principalComponent: principalPaid,
        interestComponent: interest,
        remainingPrincipalAfter: remaining,
        date: dueDate,
        type: PaymentType.emi,
        note: 'Backdated EMI',
      );
      await _paymentCol(userId, loanId).add(payment.toMap());
      await _tracker.trackWrites(1);
      await _addPersonalExpenseForPayment(userId, loan, emi, dueDate, 'EMI (Backdated)');
    }

    if (remaining < 1.0) {
      await _closeLoan(userId, loanId, loan, LoanStatus.settled);
    }
  }

  // ── Amortization schedule (computed locally) ──────────────────────────────

  /// Builds the full amortization schedule from [loan] and already-logged [payments].
  /// Paid months are marked isPaid = true.
  List<AmortizationEntry> buildSchedule(LoanModel loan, List<LoanPaymentModel> payments) {
    final entries = <AmortizationEntry>[];
    double remaining = loan.principal;
    final monthlyRate = loan.annualInterestRate / (12 * 100);

    final sortedPayments = [...payments]..sort((a, b) => a.date.compareTo(b.date));
    int emiPaymentIndex = 0;
    int partialAppliedUpTo = -1; // tracks index of last applied partial payment

    for (int i = 1; i <= loan.tenureMonths; i++) {
      final dueDate = _nthEmiDate(loan, i);

      // Apply only NEW partial payments that occurred before this due date
      for (int j = partialAppliedUpTo + 1; j < sortedPayments.length; j++) {
        final p = sortedPayments[j];
        if (p.type == PaymentType.partial && p.date.isBefore(dueDate)) {
          remaining = p.remainingPrincipalAfter;
          partialAppliedUpTo = j;
        }
      }

      final interest = remaining * monthlyRate;
      final emi = loan.baseEmi;
      final principalPaid = (emi - interest).clamp(0.0, remaining);
      final newRemaining = (remaining - principalPaid).clamp(0.0, double.infinity);

      bool isPaid = false;
      if (emiPaymentIndex < sortedPayments.length) {
        final p = sortedPayments[emiPaymentIndex];
        if (!p.date.isAfter(dueDate) && p.type == PaymentType.emi) {
          isPaid = true;
          emiPaymentIndex++;
          remaining = p.remainingPrincipalAfter;
        }
      }

      entries.add(AmortizationEntry(
        month: i,
        dueDate: dueDate,
        emi: emi,
        principal: principalPaid,
        interest: interest,
        remainingPrincipal: newRemaining,
        isPaid: isPaid,
      ));

      if (!isPaid) remaining = newRemaining;
    }

    return entries;
  }

  DateTime _nthEmiDate(LoanModel loan, int n) {
    final rawMonth = loan.startDate.month + n;
    final y = loan.startDate.year + (rawMonth - 1) ~/ 12;
    final mo = ((rawMonth - 1) % 12) + 1;
    final maxDay = DateTime(y, mo + 1, 0).day;
    return DateTime(y, mo, loan.emiDueDay.clamp(1, maxDay));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _closeLoan(String userId, String loanId, LoanModel loan, LoanStatus status) async {
    await _loanCol(userId).doc(loanId).update({'status': status.name});
    await _tracker.trackWrites(1);

    // Deactivate the linked recurring entry
    if (loan.recurringId != null) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_recurring')
          .doc(loan.recurringId)
          .update({'active': false, 'endDate': Timestamp.fromDate(DateTime.now())});
      await _tracker.trackWrites(1);
    }
  }

  Future<void> _addPersonalExpenseForPayment(
    String userId,
    LoanModel loan,
    double amount,
    DateTime date,
    String label,
  ) async {
    final month = DateFormat('yyyy-MM').format(date);
    await _personalService.addTransaction(
      userId,
      PersonalTransactionModel(
        id: '',
        title: '${loan.title} – $label',
        amount: amount,
        type: TransactionType.expense,
        category: 'Loan EMI',
        date: date,
        notes: 'Auto-logged from Loan Tracker',
        userId: userId,
        month: month,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Counts all payments (EMI + partial) to estimate months elapsed.
  /// Counts only EMI payments to estimate months elapsed (partial prepayments are not months).
  Future<int> _countPayments(String userId, String loanId) async {
    final snap = await _paymentCol(userId, loanId).get();
    _tracker.trackReads(1);
    return snap.docs.where((d) => (d['type'] as String?) == 'emi').length;
  }

  double _calcEmi(double principal, double annualRate, int months) {
    if (annualRate == 0) return principal / months;
    final r = annualRate / (12 * 100);
    double pow = 1;
    for (int i = 0; i < months; i++) pow *= (1 + r);
    return principal * r * pow / (pow - 1);
  }
}
