import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_device_gateway.dart';
import 'package:split_ex/modules/personal/domain/use_cases/sms/process_bank_sms_queue.dart';
import 'package:split_ex/modules/personal/domain/use_cases/sms/import_shared_bank_sms.dart';
import 'package:split_ex/modules/personal/domain/use_cases/sms/approve_bank_sms_review.dart';

final bankSmsControllerProvider = ChangeNotifierProvider<BankSmsController>(
  (ref) => BankSmsController(
    repository: ref.watch(bankSmsRepositoryProvider),
    device: ref.watch(bankSmsDeviceGatewayProvider),
  ),
);

class BankSmsController extends ChangeNotifier {
  final PersonalBankSmsRepository? repository;
  final BankSmsDeviceGateway device;
  BankSmsController({this.repository, required this.device});
  PersonalBankSmsRepository get _repository =>
      repository ??
      (throw StateError('Bank SMS repository is not configured.'));
  bool get supported => device.supported;
  String? userId;
  bool enabled = false, autoRecord = true, permission = false, busy = false;
  bool rcsEnabled = false, rcsPermission = false;
  int sharedImportCount = 0;
  int pendingCount = 0;
  String? error;
  List<ParsedBankSms> reviews = [];
  Set<String> trustedSenders = {};
  Future<void>? _processing;
  Future<void> _binding = Future.value();

  void start() {
    if (!supported) return;
    device.setEventHandler((method) async {
      if (method == 'queueChanged' || method == 'permissionChanged') {
        await refresh();
        if ((enabled && permission) || (rcsEnabled && rcsPermission)) {
          await process();
        }
      } else if (method == 'shareAvailable') {
        await importSharedText();
      }
    });
  }

  Future<void> bindUser(String? uid) {
    if (!supported) return Future.value();
    userId = uid;
    _binding = _binding.catchError((_) {}).then((_) async {
      await device.bindUser(uid);
      if (userId != uid) return;
      await refresh();
      if (uid != null) await _consumeSharedText(uid);
    });
    return _binding;
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final data = await device.status();
      if (data['owner'] != (userId ?? '')) return;
      enabled = data['enabled'] == true;
      autoRecord = data['autoRecord'] != false;
      permission = data['permission'] == true;
      rcsEnabled = data['rcsEnabled'] == true;
      rcsPermission = data['rcsPermission'] == true;
      pendingCount = (data['pendingCount'] as num? ?? 0).toInt();
      reviews = (data['reviews'] as List)
          .map(
            (item) =>
                ParsedBankSms.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList()
          .reversed
          .toList();
      trustedSenders = Set<String>.from(data['trustedSenders'] as List);
      final nativeError = data['lastError'] as String?;
      if (nativeError?.isNotEmpty == true) error = nativeError;
      notifyListeners();
    } on BankSmsDeviceException {
      error = 'Unable to read bank SMS settings. Reopen the app and try again.';
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    await device.requestPermission();
    await refresh();
  }

  Future<void> setRcsEnabled(bool value) async {
    await _binding;
    await device.setRcsEnabled(userId, value);
    await refresh();
  }

  Future<void> requestRcsAccess() async {
    await device.requestRcsAccess();
  }

  Future<void> importSharedText() async {
    await _binding;
    final uid = userId;
    if (uid != null) await _consumeSharedText(uid);
  }

  Future<void> _consumeSharedText(String uid) async {
    final recognized = await ImportSharedBankSms(device)(
      uid,
      isActive: () => userId == uid,
    );
    if (recognized == null) return;
    if (!recognized) {
      error =
          'The shared message was not recognized as a supported bank payment alert. You can still add it manually in Personal Transactions.';
    } else {
      error = null;
    }
    sharedImportCount++;
    await refresh();
  }

  Future<void> configure({required bool enabled, bool? automatic}) async {
    await _binding;
    await device.configure(userId, enabled, automatic ?? autoRecord);
    error = null;
    await refresh();
    if (enabled) await process();
  }

  Future<void> trust(String sender, bool trusted) async {
    await device.trust(userId, sender, trusted);
    await refresh();
  }

  Future<void> dismiss(ParsedBankSms sms) async {
    await device.deleteReview(userId, sms.messageId);
    await refresh();
  }

  Future<void> process() {
    if (_processing != null) return _processing!;
    return _processing = _process().whenComplete(() => _processing = null);
  }

  Future<void> _process() async {
    await _binding;
    if (!supported || userId == null) return;
    final uid = userId!;
    busy = true;
    notifyListeners();
    try {
      await refresh();
      if (!((enabled && permission) || (rcsEnabled && rcsPermission))) return;
      await ProcessBankSmsQueue(_repository, device)(
        userId: uid,
        isActive: () =>
            userId == uid &&
            ((enabled && permission) || (rcsEnabled && rcsPermission)),
        automatic: () => autoRecord,
        trustedSenders: () => trustedSenders,
      );
      error = null;
    } catch (_) {
      error =
          'Some bank messages are pending. Connect to the internet and retry; pending messages have been kept on this device.';
    } finally {
      busy = false;
      await refresh();
      notifyListeners();
    }
  }

  Future<BankSmsSaveResult> approve(
    ParsedBankSms sms, {
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    required BankSmsDirection direction,
    String? existingId,
    List<BankSmsDebtAllocation>? debtAllocations,
    String? accountId,
    bool asTransfer = false,
    String? fromAccountId,
    String? toAccountId,
    bool trustSender = false,
    bool rememberCategory = false,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('Sign in to record this payment.');
    final result = await ApproveBankSmsReview(_repository, device)(
      userId: uid,
      sms: sms,
      title: title,
      amount: amount,
      category: category,
      date: date,
      direction: direction,
      isActive: () => uid == userId,
      existingId: existingId,
      debtAllocations: debtAllocations,
      accountId: accountId,
      asTransfer: asTransfer,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      trustSender: trustSender,
      rememberCategory: rememberCategory,
    );
    if (uid == userId) await refresh();
    return result;
  }

  @override
  void dispose() {
    if (supported) device.setEventHandler(null);
    super.dispose();
  }
}
