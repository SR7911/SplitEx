import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/room/dependencies.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_activity_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_bill_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_expense_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_room_repository.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_settlement_repository.dart';
import 'package:split_ex/modules/room/data/datasources/receipt_upload_data_source.dart';
import 'package:split_ex/modules/room/data/datasources/receipt_pdf_data_source.dart';
import 'package:split_ex/modules/room/data/repositories/firestore_room_ledger_repository.dart';
import 'package:split_ex/shared/services/usage_tracker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

List<Override> roomDependencyOverrides() => [
  roomServiceProvider.overrideWith(
    (ref) => FirestoreRoomRepository(firestore: FirebaseFirestore.instance),
  ),
  expenseServiceProvider.overrideWith((ref) => FirestoreExpenseRepository()),
  billServiceProvider.overrideWith((ref) => FirestoreBillRepository()),
  activityServiceProvider.overrideWith((ref) => FirestoreActivityRepository()),
  settlementServiceProvider.overrideWith(
    (ref) => FirestoreSettlementRepository(),
  ),
  roomReceiptStorageProvider.overrideWith((ref) => UploadService()),
  roomReceiptExporterProvider.overrideWith((ref) => ReceiptGenerator()),
  roomLedgerRepositoryProvider.overrideWith(
    (ref) => FirestoreRoomLedgerRepository(
      firestore: FirebaseFirestore.instance,
      usageTracker: UsageTracker.instance,
    ),
  ),
];
