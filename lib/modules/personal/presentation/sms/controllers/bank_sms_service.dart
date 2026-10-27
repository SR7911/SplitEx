import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_repository.dart';

final bankSmsServiceProvider = ChangeNotifierProvider<BankSmsService>(
  (ref) => BankSmsService(repository: ref.watch(bankSmsRepositoryProvider)),
);

class BankSmsService extends ChangeNotifier {
  final PersonalBankSmsRepository? repository;
  BankSmsService({this.repository});
  PersonalBankSmsRepository get _repository => repository ??
      (throw StateError('Bank SMS repository is not configured.'));
  static const channel = MethodChannel('com.splitex.in.app/bank_sms');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  String? userId;
  bool enabled = false, autoRecord = true, permission = false, busy = false;
  int pendingCount = 0;
  String? error;
  List<ParsedBankSms> reviews = [];
  Set<String> trustedSenders = {};
  Future<void>? _processing;
  Future<void> _binding = Future.value();
  final _parser = BankSmsParser();

  void start() {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'queueChanged' || call.method == 'permissionChanged') {
        await refresh();
        if (enabled) await process();
      }
    });
  }

  Future<void> bindUser(String? uid) {
    if (!supported) return Future.value();
    userId = uid;
    _binding = _binding.catchError((_) {}).then((_) async {
      await channel.invokeMethod<void>('bindUser', {'userId': uid});
      if (userId != uid) return;
      await refresh();
    });
    return _binding;
  }

  Future<void> refresh() async {
    if (!supported) return;
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode((await channel.invokeMethod<String>('status'))!),
      );
      if (data['owner'] != (userId ?? '')) return;
      enabled = data['enabled'] == true;
      autoRecord = data['autoRecord'] != false;
      permission = data['permission'] == true;
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
    } on PlatformException {
      error = 'Unable to read bank SMS settings. Reopen the app and try again.';
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    await channel.invokeMethod<bool>('requestPermission');
    await refresh();
  }

  Future<void> configure({required bool enabled, bool? automatic}) async {
    await _binding;
    await _call('configure', {
      'enabled': enabled,
      'autoRecord': automatic ?? autoRecord,
    });
    error = null;
    await refresh();
    if (enabled) await process();
  }

  Future<void> trust(String sender, bool trusted) async {
    await _call('trust', {'sender': sender, 'trusted': trusted});
    await refresh();
  }

  Future<void> dismiss(ParsedBankSms sms) async {
    await _call('deleteReview', {'id': sms.messageId});
    await refresh();
  }

  Future<T?> _call<T>(
    String method,
    Map<String, dynamic> arguments, {
    String? owner,
  }) => channel.invokeMethod<T>(method, {
    ...arguments,
    'userId': owner ?? userId,
  });

  static bool shouldAutoRecord(
    ParsedBankSms sms, {
    required bool automatic,
    required Set<String> trusted,
    required bool hasPossibleMatch,
  }) =>
      automatic &&
      sms.canAutoRecord &&
      trusted.contains(sms.sender) &&
      !hasPossibleMatch;

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
      if (!enabled || !permission) return;
      final repo = _repository;
      final queue =
          jsonDecode((await _call<String>('queue', {}, owner: uid))!) as List;
      for (final raw in queue) {
        if (userId != uid || !enabled) break;
        final item = Map<String, dynamic>.from(raw as Map);
        if (item['owner'] != uid) continue;
        final id = item['id'] as String;
        final sms = _parser.parse(
          id: id,
          sender: item['sender'] as String,
          body: item['body'] as String,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            (item['timestamp'] as num).toInt(),
          ),
        );
        if (sms != null && !await repo.wasRecorded(uid, sms)) {
          final matches = await repo.possibleMatches(uid, sms);
          if (userId != uid || !enabled) break;
          if (shouldAutoRecord(
            sms,
            automatic: autoRecord,
            trusted: trustedSenders,
            hasPossibleMatch: matches.isNotEmpty,
          )) {
            await repo.save(
              uid,
              sms,
              matchAccount: true,
              applyMerchantRule: true,
            );
          } else {
            final data = sms.toMap();
            final reasons = [...sms.reviewReasons];
            if (!trustedSenders.contains(sms.sender)) {
              reasons.add(
                'Verify this sender before enabling automatic recording for it.',
              );
            }
            if (matches.isNotEmpty) {
              reasons.add(
                'A similar transaction already exists. Check for an EMI, settlement, or manual entry.',
              );
            }
            data['reviewReasons'] = reasons;
            await _call('putReview', {'json': jsonEncode(data)}, owner: uid);
          }
        }
        await _call('acknowledge', {'id': id}, owner: uid);
      }
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
    String? accountId,
    bool asTransfer = false,
    String? fromAccountId,
    String? toAccountId,
    bool trustSender = false,
    bool rememberCategory = false,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('Sign in to record this payment.');
    final repo = _repository;
    final result = asTransfer
        ? await repo.saveTransfer(
            uid,
            sms,
            existingId: existingId,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            date: date,
            note: title,
          )
        : await repo.save(
            uid,
            sms,
            existingId: existingId,
            accountId: accountId,
            title: title,
            amount: amount,
            category: category,
            date: date,
            direction: direction,
            rememberCategory: rememberCategory,
          );
    if (uid != userId) return result;
    if (trustSender) await trust(sms.sender, true);
    if (uid == userId) await dismiss(sms);
    return result;
  }

  @override
  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
    super.dispose();
  }
}

