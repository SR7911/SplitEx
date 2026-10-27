import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import '../../domain/entities/loans/personal_loan.dart';
import '../../domain/entities/loans/personal_loan_payment.dart';
import '../../domain/entities/loans/personal_loan_changes.dart';
import '../../domain/repositories/personal_loan_repository.dart';
import '../mappers/loans/personal_loan_firestore_mapper.dart';
import '../mappers/transactions/personal_transaction_firestore_mapper.dart';
import '../../domain/entities/transactions/personal_transaction.dart';

class FirestorePersonalLoanRepository implements PersonalLoanRepository {
  final FirebaseFirestore _db;
  final UsageTracker _tracker;

  FirestorePersonalLoanRepository({
    required FirebaseFirestore firestore,
    UsageTracker? tracker,
  }) : _db = firestore,
       _tracker = tracker ?? UsageTracker.instance;

  CollectionReference<Map<String, dynamic>> _loans(String userId) =>
      _db.collection('users').doc(userId).collection('loans');

  @override
  Stream<List<PersonalLoan>> loans(String userId) => _loans(userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        _tracker.trackReads(snapshot.docs.length);
        return snapshot.docs
            .map(
              (doc) =>
                  PersonalLoanFirestoreMapper.loanFromMap(doc.data(), doc.id),
            )
            .toList();
      });

  @override
  Stream<List<PersonalLoanPayment>> payments(String userId, String loanId) =>
      _loans(userId)
          .doc(loanId)
          .collection('payments')
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
            _tracker.trackReads(snapshot.docs.length);
            return snapshot.docs
                .map(
                  (doc) => PersonalLoanFirestoreMapper.paymentFromMap(
                    doc.data(),
                    doc.id,
                  ),
                )
                .toList();
          });

  @override
  Future<PersonalLoan> get(String userId, String loanId) async {
    final document = await _loans(userId).doc(loanId).get();
    _tracker.trackReads(1);
    final data = document.data();
    if (data == null) throw StateError('Loan not found: $loanId');
    return PersonalLoanFirestoreMapper.loanFromMap(data, loanId);
  }

  @override
  Future<String> add(String userId, PersonalLoan loan) async {
    final reference = await _loans(
      userId,
    ).add(PersonalLoanFirestoreMapper.loanToMap(loan));
    await _tracker.trackWrites(1);
    return reference.id;
  }

  @override
  Future<void> update(
    String userId,
    PersonalLoan loan,
    PersonalLoanChanges changes,
    double recurringAmount,
  ) async {
    final updates = <String, dynamic>{
      if (changes.principal != null) 'principal': changes.principal,
      if (changes.annualInterestRate != null)
        'annualInterestRate': changes.annualInterestRate,
      if (changes.tenureMonths != null) 'tenureMonths': changes.tenureMonths,
      if (changes.emiDueDay != null) 'emiDueDay': changes.emiDueDay,
      if (changes.notes != null) 'notes': changes.notes,
      if (changes.processingFee != null) 'processingFee': changes.processingFee,
      if (changes.insuranceFee != null) 'insuranceFee': changes.insuranceFee,
      if (changes.otherCharges != null) 'otherCharges': changes.otherCharges,
      if (changes.gstOnFees != null) 'gstOnFees': changes.gstOnFees,
    };
    if (changes.customEmi != null) {
      updates['customEmi'] = changes.customEmi == 0
          ? FieldValue.delete()
          : changes.customEmi;
    }
    await _loans(userId).doc(loan.id).update(updates);
    await _tracker.trackWrites(1);

    if (loan.recurringId != null) {
      await _db
          .collection('users')
          .doc(userId)
          .collection('personal_recurring')
          .doc(loan.recurringId)
          .update({
            'amount': recurringAmount,
            if (changes.emiDueDay != null) 'dayOfMonth': changes.emiDueDay,
          });
      await _tracker.trackWrites(1);
    }
  }

  @override
  Future<void> delete(String userId, String loanId) async {
    final payments = await _loans(
      userId,
    ).doc(loanId).collection('payments').get();
    for (final document in payments.docs) {
      await document.reference.delete();
    }
    await _loans(userId).doc(loanId).delete();
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> recordEmi(
    String userId,
    PersonalLoan loan,
    PersonalLoanPayment payment,
  ) async {
    final day = DateFormat('yyyy-MM-dd').format(payment.date);
    final paymentRef = _loans(
      userId,
    ).doc(loan.id).collection('payments').doc('emi_$day');
    final expenseRef = _db
        .collection('users')
        .doc(userId)
        .collection('personal_transactions')
        .doc('loan_${loan.id}_emi_$day');

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(paymentRef);
      if (existing.exists) return;
      final expense = PersonalTransaction(
        id: expenseRef.id,
        title: '${loan.title} – EMI',
        amount: payment.amount,
        type: TransactionType.expense,
        category: 'Loan EMI',
        date: payment.date,
        notes: 'Auto-logged from Loan Tracker',
        userId: userId,
        month: DateFormat('yyyy-MM').format(payment.date),
        createdAt: DateTime.now(),
      );
      transaction.set(
        paymentRef,
        PersonalLoanFirestoreMapper.paymentToMap(payment),
      );
      transaction.set(expenseRef, {
        ...PersonalTransactionFirestoreMapper.toMap(expense),
        'partialSettlements': <Map<String, dynamic>>[],
        'loanSourceId': loan.id,
      });
    });
    await _tracker.trackWrites(2);
  }

  @override
  Future<void> settle(String userId, PersonalLoan loan) =>
      _closeLoan(userId, loan, PersonalLoanStatus.settled);

  @override
  Future<void> foreclose(String userId, PersonalLoan loan) =>
      _closeLoan(userId, loan, PersonalLoanStatus.foreclosed);

  Future<void> _closeLoan(
    String userId,
    PersonalLoan loan,
    PersonalLoanStatus status,
  ) async {
    await _loans(userId).doc(loan.id).update({'status': status.name});
    await _tracker.trackWrites(1);
    if (loan.recurringId != null) {
      await _db
          .collection('users')
          .doc(userId)
          .collection('personal_recurring')
          .doc(loan.recurringId)
          .update({
            'active': false,
            'endDate': Timestamp.fromDate(DateTime.now()),
          });
      await _tracker.trackWrites(1);
    }
  }

  @override
  Future<void> recordPartialPayment(
    String userId,
    PersonalLoan loan,
    PersonalLoanPayment payment,
  ) async {
    await _loans(userId)
        .doc(loan.id)
        .collection('payments')
        .add(PersonalLoanFirestoreMapper.paymentToMap(payment));
    await _tracker.trackWrites(1);
    await _addPersonalExpenseForPayment(
      userId,
      loan,
      payment.amount,
      payment.date,
      'Partial Payment',
    );
  }

  @override
  Future<void> recordForeclosure(
    String userId,
    PersonalLoan loan,
    PersonalLoanPayment payment,
  ) async {
    await _loans(userId)
        .doc(loan.id)
        .collection('payments')
        .add(PersonalLoanFirestoreMapper.paymentToMap(payment));
    await _tracker.trackWrites(1);
    await _addPersonalExpenseForPayment(
      userId,
      loan,
      payment.amount,
      payment.date,
      'Foreclosure',
    );
  }

  Future<void> _addPersonalExpenseForPayment(
    String userId,
    PersonalLoan loan,
    double amount,
    DateTime date,
    String label,
  ) async {
    final month = DateFormat('yyyy-MM').format(date);
    final transactions = _db
        .collection('users')
        .doc(userId)
        .collection('personal_transactions');
    final existing = await transactions
        .where('loanSourceId', isEqualTo: loan.id)
        .where('month', isEqualTo: month)
        .get();
    _tracker.trackReads(existing.docs.length);
    final day = DateFormat('yyyy-MM-dd').format(date);
    final alreadyLogged = existing.docs.any((document) {
      final timestamp = document.data()['date'] as Timestamp?;
      return timestamp != null &&
          DateFormat('yyyy-MM-dd').format(timestamp.toDate()) == day;
    });
    if (alreadyLogged) return;

    final expense = PersonalTransaction(
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
    );
    await transactions.add({
      ...PersonalTransactionFirestoreMapper.toMap(expense),
      'partialSettlements': <Map<String, dynamic>>[],
      'loanSourceId': loan.id,
    });
    await _tracker.trackWrites(1);
  }

  @override
  Future<int> countEmiPayments(String userId, String loanId) async {
    final snapshot = await _loans(
      userId,
    ).doc(loanId).collection('payments').get();
    _tracker.trackReads(1);
    return snapshot.docs
        .where((document) => document.data()['type'] == 'emi')
        .length;
  }

  @override
  Future<void> updateRecurringAmount(
    String userId,
    String recurringId,
    double amount,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('personal_recurring')
        .doc(recurringId)
        .update({'amount': amount});
    await _tracker.trackWrites(1);
  }
}
