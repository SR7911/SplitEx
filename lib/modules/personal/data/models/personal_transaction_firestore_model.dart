import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/transactions/personal_transaction.dart';
import '../../domain/entities/transactions/expense_split.dart';

/// The Firestore boundary for fields shared by Personal transactions.
/// Historical documents may lack optional fields; retain their existing defaults.
class PersonalTransactionFirestoreMapper {
  static PersonalTransaction fromMap(Map<String, dynamic> map, String id) =>
      PersonalTransaction(
        id: id,
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        type: TransactionType.values.firstWhere(
          (value) => value.name == map['type'],
          orElse: () => TransactionType.expense,
        ),
        category: map['category'] ?? 'Other',
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        notes: map['notes'],
        userId: map['userId'] ?? '',
        month: map['month'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        accountId: map['accountId'] as String?,
        dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
        debtType: map['debtType'] != null
            ? DebtType.values.firstWhere(
                (value) => value.name == map['debtType'],
                orElse: () => DebtType.lent,
              )
            : null,
        personName: map['personName'],
        isSettled: map['isSettled'] ?? false,
        settledAmount: (map['settledAmount'] ?? 0).toDouble(),
        writtenOffAmount: (map['writtenOffAmount'] ?? 0).toDouble(),
        settlements: settlementsFromRaw(map['partialSettlements']),
        split: splitFromRaw(map),
        splitSourceId: map['splitSourceId'] as String?,
        debtSourceId: map['debtSourceId'] as String?,
      );

  static List<DebtSettlement> settlementsFromRaw(Object? raw) =>
      List<Map<String, dynamic>>.from(raw is Iterable ? raw : const []).map((
        entry,
      ) {
        return DebtSettlement(
          amount: (entry['amount'] as num? ?? 0).toDouble(),
          date: DateTime.tryParse(entry['date']?.toString() ?? ''),
          note: (entry['note'] as String? ?? '').trim(),
          isWriteOff: entry['type'] == 'writeOff',
          isTally: entry['type'] == 'tally',
          isCashEntry: entry['cashEntry'] == true,
          repaymentId: entry['repaymentId'] as String?,
          accountId: entry['accountId'] as String?,
          bankSmsReceiptId: entry['bankSmsReceiptId'] as String?,
        );
      }).toList();

  static ExpenseSplit? splitFromRaw(Map<String, dynamic> map) {
    final raw = map['splitShares'];
    if (raw is! Iterable || raw.isEmpty) return null;
    return ExpenseSplit(
      mode: map['splitMode'] == 'manual'
          ? ExpenseSplitMode.manual
          : ExpenseSplitMode.equal,
      shares: [
        for (final item in raw)
          if (item is Map)
            ExpenseSplitShare(
              personName: item['personName']?.toString() ?? '',
              amount: (item['amount'] as num? ?? 0).toDouble(),
              debtId: item['debtId'] as String?,
            ),
      ],
    );
  }

  static List<Map<String, dynamic>> splitSharesToRaw(ExpenseSplit split) => [
    for (final share in split.shares)
      {
        'personName': share.personName,
        'amount': share.amount,
        if (share.debtId != null) 'debtId': share.debtId,
      },
  ];

  static Map<String, dynamic> toMap(PersonalTransaction transaction) => {
    'title': transaction.title,
    'amount': transaction.amount,
    'type': transaction.type.name,
    'category': transaction.category,
    'date': Timestamp.fromDate(transaction.date),
    'notes': transaction.notes,
    'userId': transaction.userId,
    'month': transaction.month,
    'createdAt': FieldValue.serverTimestamp(),
    if (transaction.accountId != null) 'accountId': transaction.accountId,
    if (transaction.dueDate != null)
      'dueDate': Timestamp.fromDate(transaction.dueDate!),
    if (transaction.debtType != null) 'debtType': transaction.debtType!.name,
    if (transaction.personName != null) 'personName': transaction.personName,
    'isSettled': transaction.isSettled,
    'settledAmount': transaction.settledAmount,
    'writtenOffAmount': transaction.writtenOffAmount,
    if (transaction.split != null) ...{
      'splitMode': transaction.split!.mode.name,
      'splitShares': splitSharesToRaw(transaction.split!),
    },
    if (transaction.splitSourceId != null)
      'splitSourceId': transaction.splitSourceId,
    if (transaction.debtSourceId != null)
      'debtSourceId': transaction.debtSourceId,
  };
}
