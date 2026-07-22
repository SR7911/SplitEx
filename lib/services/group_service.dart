import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/models/group_model.dart';
import 'package:split_ex/models/group_expense_model.dart';
import 'package:split_ex/services/balance_service.dart';

class GroupService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<GroupModel> createGroup({
    required String name,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required String createdBy,
    String currency = '₹',
  }) async {
    final code = _generateCode();
    final doc = _groups.doc();
    final group = GroupModel(
      id: doc.id,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      inviteCode: code,
      createdBy: createdBy,
      memberIds: [createdBy],
      createdAt: DateTime.now(),
    );
    await doc.set(group.toMap());
    return group;
  }

  Future<GroupModel?> joinByCode(String code, String userId) async {
    final snap = await _groups.where('inviteCode', isEqualTo: code.toUpperCase()).limit(1).get();
    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final group = GroupModel.fromMap(doc.data(), doc.id);

    if (group.isArchived) throw Exception('This group is archived.');
    if (group.isMember(userId)) throw Exception('Already a member.');

    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    return GroupModel.fromMap({...doc.data(), 'memberIds': [...group.memberIds, userId]}, doc.id);
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> archiveGroup(String groupId) async {
    await _groups.doc(groupId).update({'status': GroupStatus.archived.name});
  }

  Future<void> restoreGroup(String groupId) async {
    await _groups.doc(groupId).update({'status': GroupStatus.active.name});
  }

  Stream<List<GroupModel>> getUserGroupsStream(String userId) {
    return _groups
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => GroupModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<GroupModel?> getGroupStream(String groupId) {
    return _groups.doc(groupId).snapshots().map(
          (d) => d.exists ? GroupModel.fromMap(d.data()!, d.id) : null,
        );
  }
}

class GroupExpenseService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _expensesRef(String groupId) =>
      _db.collection('groups').doc(groupId).collection('expenses');

  Future<GroupExpenseModel> addExpense(GroupExpenseModel expense) async {
    final doc = _expensesRef(expense.groupId).doc();
    await doc.set(expense.toMap());
    return GroupExpenseModel.fromMap(
        {...expense.toMap(), 'createdAt': Timestamp.now()}, doc.id);
  }

  Future<void> updateExpense(String groupId, String expenseId, Map<String, dynamic> data) async {
    await _expensesRef(groupId).doc(expenseId).update(data);
  }

  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _expensesRef(groupId).doc(expenseId).delete();
  }

  Stream<List<GroupExpenseModel>> getExpensesStream(String groupId) {
    return _expensesRef(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => GroupExpenseModel.fromMap(d.data(), d.id)).toList());
  }
}

class GroupBalanceService {
  /// Reuses existing BalanceService logic adapted for GroupExpenseModel.
  Map<String, double> computeNetBalances({
    required List<GroupExpenseModel> expenses,
    required List<String> memberIds,
  }) {
    final balances = {for (final id in memberIds) id: 0.0};
    for (final expense in expenses) {
      final payer = expense.paidBy;
      final splitAmong = expense.splitAmong;
      if (splitAmong.isEmpty) continue;

      balances[payer] = (balances[payer] ?? 0) + expense.amount;
      for (final member in splitAmong) {
        balances[member] = (balances[member] ?? 0) - expense.shareFor(member);
      }
    }
    return balances;
  }

  List<Debt> simplifyDebts(Map<String, double> netBalances) {
    return BalanceService().simplifyDebts(netBalances);
  }
}
