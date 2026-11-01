import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import '../../domain/entities/budgets/personal_budget.dart';
import '../../domain/repositories/personal_budget_repository.dart';
import '../models/personal_budget_firestore_model.dart';
import '../datasources/personal_firestore_data_source.dart';

class FirestorePersonalBudgetRepository implements PersonalBudgetRepository {
  final FirebaseFirestore _db;
  late final PersonalFirestoreDataSource _source = PersonalFirestoreDataSource(
    _db,
  );
  final UsageTracker _tracker;

  FirestorePersonalBudgetRepository({
    required FirebaseFirestore firestore,
    UsageTracker? tracker,
  }) : _db = firestore,
       _tracker = tracker ?? UsageTracker.instance;

  CollectionReference<Map<String, dynamic>> _budgets(String userId) =>
      _source.budgets(userId);

  @override
  Stream<List<PersonalBudget>> budgetsForMonth(String userId, String month) {
    _tracker.trackReads(1);
    return _budgets(userId).where('month', isEqualTo: month).snapshots().map((
      snapshot,
    ) {
      _tracker.trackReads(snapshot.docs.length);
      return snapshot.docs
          .map(
            (doc) => PersonalBudgetFirestoreMapper.fromMap(doc.data(), doc.id),
          )
          .toList();
    });
  }

  @override
  Future<void> save(String userId, PersonalBudget budget) async {
    final existing = await _budgets(userId)
        .where('category', isEqualTo: budget.category)
        .where('month', isEqualTo: budget.month)
        .limit(1)
        .get();
    await _tracker.trackReads(1);
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({'budget': budget.budget});
    } else {
      await _budgets(userId).add(PersonalBudgetFirestoreMapper.toMap(budget));
    }
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> delete(String userId, String id) async {
    await _budgets(userId).doc(id).delete();
    await _tracker.trackWrites(1);
  }
}
