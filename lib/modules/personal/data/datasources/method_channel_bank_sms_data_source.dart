import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:split_ex/modules/personal/domain/repositories/bank_sms_device_gateway.dart';

class MethodChannelBankSmsDataSource implements BankSmsDeviceGateway {
  static const channel = MethodChannel('com.splitex.in.app/bank_sms');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void setEventHandler(Future<void> Function(String method)? handler) {
    channel.setMethodCallHandler(
      handler == null ? null : (call) => handler(call.method),
    );
  }

  @override
  Future<void> bindUser(String? userId) =>
      channel.invokeMethod<void>('bindUser', {'userId': userId});

  @override
  Future<Map<String, dynamic>> status() async {
    try {
      return Map<String, dynamic>.from(
        jsonDecode((await channel.invokeMethod<String>('status'))!),
      );
    } on PlatformException {
      throw const BankSmsDeviceException();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> queue(String userId) async {
    final values =
        jsonDecode(
              (await channel.invokeMethod<String>('queue', {
                'userId': userId,
              }))!,
            )
            as List;
    return values
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  @override
  Future<void> requestPermission() async {
    await channel.invokeMethod<bool>('requestPermission');
  }

  @override
  Future<void> requestRcsAccess() async {
    await channel.invokeMethod<bool>('requestRcsAccess');
  }

  @override
  Future<void> setRcsEnabled(String? userId, bool enabled) =>
      channel.invokeMethod<void>('setRcsEnabled', {
        'enabled': enabled,
        'userId': userId,
      });

  @override
  Future<String?> consumeShare(String userId) =>
      channel.invokeMethod<String>('consumeShare', {'userId': userId});

  @override
  Future<void> putReview(String userId, Map<String, dynamic> review) =>
      channel.invokeMethod<void>('putReview', {
        'json': jsonEncode(review),
        'userId': userId,
      });

  @override
  Future<void> configure(String? userId, bool enabled, bool autoRecord) =>
      channel.invokeMethod<void>('configure', {
        'enabled': enabled,
        'autoRecord': autoRecord,
        'userId': userId,
      });

  @override
  Future<void> trust(String? userId, String sender, bool trusted) =>
      channel.invokeMethod<void>('trust', {
        'sender': sender,
        'trusted': trusted,
        'userId': userId,
      });

  @override
  Future<void> deleteReview(String? userId, String messageId) => channel
      .invokeMethod<void>('deleteReview', {'id': messageId, 'userId': userId});

  @override
  Future<void> acknowledge(String userId, String messageId) => channel
      .invokeMethod<void>('acknowledge', {'id': messageId, 'userId': userId});

  @override
  Future<void> backgroundComplete(bool retry) =>
      channel.invokeMethod<void>('backgroundComplete', {'retry': retry});
}
