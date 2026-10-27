import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/personal/domain/entities/savings/savings_goal.dart';

SavingsGoal savingsGoalFromFirestore(Map<String, dynamic> data, String id) =>
    SavingsGoal(
      id: id,
      title: data['title'] as String,
      targetMinor: (data['targetMinor'] as num).toInt(),
      savedMinor: (data['savedMinor'] as num? ?? 0).toInt(),
      targetDate: (data['targetDate'] as Timestamp?)?.toDate(),
      accountId: data['accountId'] as String?,
      archived: data['archived'] == true,
    );

SavingsEntry savingsEntryFromFirestore(Map<String, dynamic> data, String id) =>
    SavingsEntry(
      id: id,
      amountMinor: (data['amountMinor'] as num).toInt(),
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] as String? ?? '',
    );
