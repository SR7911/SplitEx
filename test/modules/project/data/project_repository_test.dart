import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ex/modules/project/data/repositories/firestore_project_repositories.dart';
import 'package:split_ex/modules/project/domain/entities/project_model.dart';
import 'package:split_ex/modules/project/domain/entities/project_update.dart';
import 'package:split_ex/modules/project/domain/entities/project_expense_update.dart';
import 'package:split_ex/modules/project/domain/use_cases/record_project_partial_payment.dart';
import 'package:split_ex/modules/project/domain/use_cases/settle_project_debt.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreProjectRepository projects;
  late FirestoreProjectExpenseRepository expenses;
  final date = DateTime(2026, 10, 29);

  setUp(() {
    db = FakeFirebaseFirestore();
    projects = FirestoreProjectRepository(firestore: db);
    expenses = FirestoreProjectExpenseRepository(firestore: db);
  });

  test('project and expense edits keep user-scoped document shape', () async {
    final project = await projects.createProject(
      uid: 'alice',
      name: 'Wedding',
      projectType: 'Event',
      estimatedBudget: 50000,
      startDate: date,
    );
    final projectDoc = await db.doc('users/alice/projects/${project.id}').get();
    expect(projectDoc.data()?['startDate'], isA<Timestamp>());
    expect(projectDoc.data()?['status'], 'active');

    await projects.updateProject(
      'alice',
      project.id,
      ProjectUpdate(
        name: 'Wedding day',
        projectType: 'Event',
        estimatedBudget: 60000,
        startDate: date,
        status: ProjectStatus.paused,
      ),
    );
    expect(
      (await db.doc('users/alice/projects/${project.id}').get())
          .data()?['status'],
      'paused',
    );

    final expense = ProjectExpenseModel(
      id: '',
      projectId: project.id,
      title: 'Venue',
      amount: 1000,
      category: 'Venue',
      date: date,
      createdBy: 'alice',
      createdAt: date,
      debtType: ProjectDebtType.lent,
      personName: 'Bob',
    );
    final saved = await expenses.addExpense('alice', expense);
    final path = 'users/alice/projects/${project.id}/expenses/${saved.id}';
    expect((await db.doc(path).get()).data()?['paymentMethod'], 'cash');
    expect((await db.doc(path).get()).data()?['date'], isA<Timestamp>());

    await expenses.updateExpense(
      'alice',
      project.id,
      saved.id,
      ProjectExpenseUpdate(
        title: 'New Venue',
        amount: 1200,
        category: 'Venue',
        paymentMethod: PaymentMethod.upi,
        date: date,
        debtType: ProjectDebtType.lent,
        personName: 'Bob',
        isSettled: false,
      ),
    );
    final updated = await db.doc(path).get();
    expect(updated.data()?['title'], 'New Venue');
    expect(updated.data()?['paymentMethod'], 'upi');
    expect(updated.data()?['debtType'], 'lent');
  });

  test('debt payment use cases retain history and settled totals', () async {
    final project = await projects.createProject(
      uid: 'alice',
      name: 'Home',
      projectType: 'Other',
      estimatedBudget: 1000,
      startDate: date,
    );
    final expense = ProjectExpenseModel(
      id: '',
      projectId: project.id,
      title: 'Loan',
      amount: 1000,
      category: 'Other',
      date: date,
      createdBy: 'alice',
      createdAt: date,
      debtType: ProjectDebtType.borrowed,
      personName: 'Bob',
    );
    final saved = await expenses.addExpense('alice', expense);

    await RecordProjectPartialPayment(expenses)(
      'alice',
      project.id,
      saved.id,
      300,
      'First payment',
    );
    final path = 'users/alice/projects/${project.id}/expenses/${saved.id}';
    final partial = (await db.doc(path).get()).data()!;
    expect(partial['settledAmount'], 300);
    expect(partial['isSettled'], false);
    expect(
      (partial['partialSettlements'] as List).single['note'],
      'First payment',
    );
    expect(
      (partial['partialSettlements'] as List).single['date'],
      isA<String>(),
    );
    final read =
        (await expenses.getExpensesStream('alice', project.id).first).single;
    expect(read.partialSettlements.single.amount, 300);
    expect(read.partialSettlements.single.note, 'First payment');
    expect(read.partialSettlements.single.date, isA<DateTime>());

    await SettleProjectDebt(expenses)('alice', project.id, saved.id);
    final full = (await db.doc(path).get()).data()!;
    expect(full['isSettled'], true);
    expect(full['settledAmount'], 1000);
    expect(full['partialSettlements'], hasLength(2));
    expect(
      (full['partialSettlements'] as List).last['note'],
      'Full settlement',
    );
  });

  test('invalid partial payment is rejected before persistence', () async {
    expect(
      () => RecordProjectPartialPayment(expenses)(
        'alice',
        'project',
        'debt',
        -1,
        null,
      ),
      throwsArgumentError,
    );
    expect(
      (await db.collection('users/alice/projects/project/expenses').get()).docs,
      isEmpty,
    );
  });
}
