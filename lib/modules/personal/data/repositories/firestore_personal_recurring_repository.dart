import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import '../../domain/entities/recurring/personal_recurring_edit.dart';
import '../../domain/entities/recurring/personal_recurring_entry.dart';
import '../../domain/repositories/personal_recurring_repository.dart';
import '../mappers/recurring/personal_recurring_firestore_mapper.dart';

class FirestorePersonalRecurringRepository
    implements PersonalRecurringRepository {
  final FirebaseFirestore _db;
  final UsageTracker _tracker;

  FirestorePersonalRecurringRepository({
    required FirebaseFirestore firestore,
    UsageTracker? tracker,
  }) : _db = firestore,
       _tracker = tracker ?? UsageTracker.instance;

  CollectionReference<Map<String, dynamic>> _entries(String userId) =>
      _db.collection('users').doc(userId).collection('personal_recurring');

  @override
  Stream<List<PersonalRecurringEntry>> entries(String userId) {
    _tracker.trackReads(1);
    return _entries(userId).orderBy('dayOfMonth').snapshots().map((snapshot) {
      _tracker.trackReads(snapshot.docs.length);
      return snapshot.docs
          .map(
            (doc) =>
                PersonalRecurringFirestoreMapper.fromMap(doc.data(), doc.id),
          )
          .toList();
    });
  }

  @override
  Future<void> add(String userId, PersonalRecurringEntry entry) async {
    await _entries(userId).add({
      ...PersonalRecurringFirestoreMapper.toMap(entry),
      'createdAt': Timestamp.fromDate(entry.createdAt ?? DateTime.now()),
    });
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> update(
    String userId,
    PersonalRecurringEntry current,
    PersonalRecurringChanges changes,
  ) async {
    final snapshot = PersonalRecurringEdit(
      title: current.title,
      amount: current.amount,
      category: current.category,
      frequency: current.frequency,
      dayOfMonth: current.dayOfMonth,
      endDate: current.endDate,
      editedAt: DateTime.now(),
    );
    final history = [
      snapshot,
      ...current.editHistory,
    ].map(PersonalRecurringFirestoreMapper.editToMap).toList();
    final updates = <String, dynamic>{
      'editHistory': history,
      if (changes.title != null) 'title': changes.title,
      if (changes.amount != null) 'amount': changes.amount,
      if (changes.category != null) 'category': changes.category,
      if (changes.frequency != null) 'frequency': changes.frequency!.name,
      if (changes.dayOfMonth != null) 'dayOfMonth': changes.dayOfMonth,
    };
    if (changes.clearEndDate) {
      updates['endDate'] = FieldValue.delete();
    } else if (changes.endDate != null) {
      updates['endDate'] = Timestamp.fromDate(changes.endDate!);
    }
    await _entries(userId).doc(current.id).update(updates);
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> toggle(String userId, String id, bool active) async {
    await _entries(userId).doc(id).update({'active': active});
    await _tracker.trackWrites(1);
  }

  @override
  Future<void> delete(String userId, String id) async {
    await _entries(userId).doc(id).delete();
    await _tracker.trackWrites(1);
  }
}
