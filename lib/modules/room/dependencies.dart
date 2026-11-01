import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/repositories/activity_repository.dart';
import 'domain/repositories/bill_repository.dart';
import 'domain/repositories/expense_repository.dart';
import 'domain/repositories/room_repository.dart';
import 'domain/repositories/settlement_repository.dart';
import 'domain/repositories/room_ledger_repository.dart';
import 'domain/use_cases/record_room_expense.dart';
import 'domain/use_cases/edit_room_expense.dart';
import 'domain/use_cases/delete_room_expense.dart';
import 'domain/use_cases/record_room_bill.dart';
import 'domain/use_cases/delete_room_bill.dart';
import 'domain/use_cases/record_room_settlement.dart';
import 'domain/use_cases/confirm_room_settlement.dart';
import 'domain/use_cases/join_room.dart';
import 'domain/repositories/room_receipt_storage.dart';
import 'domain/repositories/room_receipt_exporter.dart';

final roomServiceProvider = Provider<RoomRepository>(
  (ref) => throw StateError('Room repository is not configured.'),
);
final expenseServiceProvider = Provider<ExpenseRepository>(
  (ref) => throw StateError('Room expense repository is not configured.'),
);
final billServiceProvider = Provider<BillRepository>(
  (ref) => throw StateError('Room bill repository is not configured.'),
);
final activityServiceProvider = Provider<ActivityRepository>(
  (ref) => throw StateError('Room activity repository is not configured.'),
);
final settlementServiceProvider = Provider<SettlementRepository>(
  (ref) => throw StateError('Room settlement repository is not configured.'),
);
final roomLedgerRepositoryProvider = Provider<RoomLedgerRepository>(
  (ref) => throw StateError('Room ledger repository is not configured.'),
);

final recordRoomExpenseProvider = Provider(
  (ref) => RecordRoomExpense(ref.watch(roomLedgerRepositoryProvider)),
);
final editRoomExpenseProvider = Provider(
  (ref) => EditRoomExpense(ref.watch(roomLedgerRepositoryProvider)),
);
final deleteRoomExpenseProvider = Provider(
  (ref) => DeleteRoomExpense(ref.watch(roomLedgerRepositoryProvider)),
);
final recordRoomBillProvider = Provider(
  (ref) => RecordRoomBill(ref.watch(roomLedgerRepositoryProvider)),
);
final deleteRoomBillProvider = Provider(
  (ref) => DeleteRoomBill(ref.watch(roomLedgerRepositoryProvider)),
);
final recordRoomSettlementProvider = Provider(
  (ref) => RecordRoomSettlement(ref.watch(roomLedgerRepositoryProvider)),
);
final confirmRoomSettlementProvider = Provider(
  (ref) => ConfirmRoomSettlement(ref.watch(roomLedgerRepositoryProvider)),
);
final joinRoomProvider = Provider(
  (ref) => JoinRoom(ref.watch(roomServiceProvider)),
);

final roomReceiptStorageProvider = Provider<RoomReceiptStorage>(
  (ref) => throw StateError('Room receipt storage is not configured.'),
);
final roomReceiptExporterProvider = Provider<RoomReceiptExporter>(
  (ref) => throw StateError('Room receipt exporter is not configured.'),
);
