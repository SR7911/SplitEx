import 'package:split_ex/modules/personal/data/mappers/transactions/personal_transaction_firestore_mapper.dart';
import 'package:split_ex/modules/personal/data/mappers/budgets/personal_budget_firestore_mapper.dart';
import 'package:split_ex/modules/personal/domain/entities/budgets/personal_budget.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart';

export 'package:split_ex/modules/personal/domain/entities/transactions/personal_transaction.dart'
    show TransactionType, DebtType;

class PersonalTransactionModel extends PersonalTransaction {
  // Debt tracking fields
  final List<Map<String, dynamic>> partialSettlements;

  PersonalTransactionModel({
    required String id,
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String? notes,
    required String userId,
    required String month,
    required DateTime createdAt,
    String? accountId,
    DateTime? dueDate,
    DebtType? debtType,
    String? personName,
    bool isSettled = false,
    double settledAmount = 0,
    double writtenOffAmount = 0,
    this.partialSettlements = const [],
  }) : super(
         id: id,
         title: title,
         amount: amount,
         type: type,
         category: category,
         date: date,
         notes: notes,
         userId: userId,
         month: month,
         createdAt: createdAt,
         accountId: accountId,
         dueDate: dueDate,
         debtType: debtType,
         personName: personName,
         isSettled: isSettled,
         settledAmount: settledAmount,
         writtenOffAmount: writtenOffAmount,
         settlements: PersonalTransactionFirestoreMapper.settlementsFromRaw(
           partialSettlements,
         ),
       );

  factory PersonalTransactionModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    final transaction = PersonalTransactionFirestoreMapper.fromMap(map, id);
    return PersonalTransactionModel(
      id: transaction.id,
      title: transaction.title,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      date: transaction.date,
      notes: transaction.notes,
      userId: transaction.userId,
      month: transaction.month,
      createdAt: transaction.createdAt,
      accountId: transaction.accountId,
      dueDate: transaction.dueDate,
      debtType: transaction.debtType,
      personName: transaction.personName,
      isSettled: transaction.isSettled,
      settledAmount: transaction.settledAmount,
      writtenOffAmount: transaction.writtenOffAmount,
      partialSettlements: List<Map<String, dynamic>>.from(
        map['partialSettlements'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...PersonalTransactionFirestoreMapper.toMap(this),
      'partialSettlements': partialSettlements,
    };
  }
}

class CategoryBudget extends PersonalBudget {
  const CategoryBudget({
    required super.id,
    required super.category,
    required super.budget,
    required super.userId,
    required super.month,
  });

  factory CategoryBudget.fromMap(Map<String, dynamic> map, String id) {
    final budget = PersonalBudgetFirestoreMapper.fromMap(map, id);
    return CategoryBudget(
      id: budget.id,
      category: budget.category,
      budget: budget.budget,
      userId: budget.userId,
      month: budget.month,
    );
  }

  Map<String, dynamic> toMap() => PersonalBudgetFirestoreMapper.toMap(this);
}
