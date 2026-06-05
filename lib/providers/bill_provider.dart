import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/bill_model.dart';
import 'package:split_ex/providers/expense_provider.dart';
import 'package:split_ex/services/bill_service.dart';

final billServiceProvider = Provider<BillService>((ref) => BillService());

class MonthBillKey {
  final String roomId;
  final String month;
  const MonthBillKey({required this.roomId, required this.month});

  @override
  bool operator ==(Object other) =>
      other is MonthBillKey && roomId == other.roomId && month == other.month;

  @override
  int get hashCode => Object.hash(roomId, month);
}

final billsStreamProvider =
    StreamProvider.family<List<BillModel>, MonthBillKey>((ref, key) {
  return ref.watch(billServiceProvider).getBillsStream(key.roomId, key.month);
});
