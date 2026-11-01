import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/group/data/datasources/group_firestore_data_source.dart';
import 'package:split_ex/modules/group/data/models/group_firestore_models.dart';
import 'package:split_ex/modules/group/domain/entities/group_model.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_model.dart';
import 'package:split_ex/modules/group/domain/entities/group_expense_update.dart';
import 'package:split_ex/modules/group/domain/repositories/group_repository.dart';
import 'package:split_ex/modules/group/domain/repositories/group_expense_repository.dart';
import 'package:split_ex/modules/group/domain/repositories/group_settlement_repository.dart';
import 'package:split_ex/shared/data/mappers/settlement_firestore_mapper.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

class FirestoreGroupRepository implements GroupRepository {
  final GroupFirestoreDataSource _source;
  FirestoreGroupRepository({
    FirebaseFirestore? firestore,
    GroupFirestoreDataSource? source,
  }) : _source =
           source ??
           GroupFirestoreDataSource(firestore ?? FirebaseFirestore.instance);

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    required String createdBy,
    String currency = '₹',
  }) async {
    final group = GroupModel(
      id: '',
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      currency: currency,
      inviteCode: _generateCode(),
      createdBy: createdBy,
      memberIds: [createdBy],
      createdAt: DateTime.now(),
    );
    final (id, data) = await _source.createGroup(
      GroupFirestoreMapper.toMap(group),
    );
    return GroupFirestoreMapper.fromMap(data, id);
  }

  @override
  Future<GroupModel?> findByInviteCode(String inviteCode) async {
    final document = await _source.findByInviteCode(inviteCode);
    return document == null
        ? null
        : GroupFirestoreMapper.fromMap(document.$2, document.$1);
  }

  @override
  Future<GroupModel> addMember(String groupId, String userId) async =>
      GroupFirestoreMapper.fromMap(
        await _source.addMember(groupId, userId),
        groupId,
      );
  @override
  Future<void> leaveGroup(String groupId, String userId) =>
      _source.leaveGroup(groupId, userId);
  @override
  Future<void> archiveGroup(String groupId) =>
      _source.setGroupStatus(groupId, GroupStatus.archived.name);
  @override
  Future<void> restoreGroup(String groupId) =>
      _source.setGroupStatus(groupId, GroupStatus.active.name);
  @override
  Stream<List<GroupModel>> getUserGroupsStream(String userId) => _source
      .watchUserGroups(userId)
      .map(
        (documents) => documents
            .map(
              (document) =>
                  GroupFirestoreMapper.fromMap(document.$2, document.$1),
            )
            .toList(),
      );
  @override
  Stream<GroupModel?> getGroupStream(String groupId) => _source
      .watchGroup(groupId)
      .map(
        (data) =>
            data == null ? null : GroupFirestoreMapper.fromMap(data, groupId),
      );
}

class FirestoreGroupExpenseRepository implements GroupExpenseRepository {
  final GroupFirestoreDataSource _source;
  FirestoreGroupExpenseRepository({
    FirebaseFirestore? firestore,
    GroupFirestoreDataSource? source,
  }) : _source =
           source ??
           GroupFirestoreDataSource(firestore ?? FirebaseFirestore.instance);
  @override
  Future<GroupExpenseModel> addExpense(GroupExpenseModel expense) async {
    final (id, data) = await _source.addExpense(
      expense.groupId,
      GroupExpenseFirestoreMapper.toMap(expense),
    );
    return GroupExpenseFirestoreMapper.fromMap(data, id);
  }

  @override
  Future<void> updateExpense(
    String groupId,
    String expenseId,
    GroupExpenseUpdate changes,
  ) => _source.updateExpense(
    groupId,
    expenseId,
    GroupExpenseFirestoreMapper.toUpdateMap(changes),
  );
  @override
  Future<void> deleteExpense(String groupId, String expenseId) =>
      _source.deleteExpense(groupId, expenseId);
  @override
  Stream<List<GroupExpenseModel>> getExpensesStream(String groupId) =>
      _source.watchExpenses(groupId).map((documents) {
        final expenses = documents
            .map(
              (document) =>
                  GroupExpenseFirestoreMapper.fromMap(document.$2, document.$1),
            )
            .toList();
        expenses.sort((a, b) => b.date.compareTo(a.date));
        return expenses;
      });
}

class FirestoreGroupSettlementRepository implements GroupSettlementRepository {
  final GroupFirestoreDataSource _source;
  FirestoreGroupSettlementRepository({
    FirebaseFirestore? firestore,
    GroupFirestoreDataSource? source,
  }) : _source =
           source ??
           GroupFirestoreDataSource(firestore ?? FirebaseFirestore.instance);
  @override
  Future<void> createSettlement(String groupId, SettlementModel settlement) =>
      _source.createSettlement(groupId, {
        ...SettlementFirestoreMapper.toMap(settlement),
        'roomId': groupId,
      });
  @override
  Future<void> confirmSettlement(String groupId, String settlementId) =>
      _source.updateSettlement(groupId, settlementId, {
        'status': SettlementStatus.confirmed.name,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
  @override
  Future<void> cancelSettlement(String groupId, String settlementId) =>
      _source.updateSettlement(groupId, settlementId, {
        'status': SettlementStatus.cancelled.name,
      });
  @override
  Stream<List<SettlementModel>> getSettlementsStream(String groupId) => _source
      .watchSettlements(groupId)
      .map(
        (documents) => documents
            .map(
              (document) =>
                  SettlementFirestoreMapper.fromMap(document.$2, document.$1),
            )
            .toList(),
      );
}
