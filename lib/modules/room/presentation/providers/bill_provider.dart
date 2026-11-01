import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/dependencies.dart';
export 'package:split_ex/modules/room/dependencies.dart' show billServiceProvider;

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
