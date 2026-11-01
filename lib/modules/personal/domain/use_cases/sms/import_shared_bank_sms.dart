import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../policies/sms/bank_sms_parser.dart';
import '../../repositories/bank_sms_device_gateway.dart';

/// Returns null when no share is pending, false when parsing fails, true when queued.
class ImportSharedBankSms {
  final BankSmsDeviceGateway device;
  final BankSmsParser parser;
  final DateTime Function() clock;

  ImportSharedBankSms(
    this.device, {
    BankSmsParser? parser,
    DateTime Function()? clock,
  }) : parser = parser ?? BankSmsParser(),
       clock = clock ?? DateTime.now;

  Future<bool?> call(String userId, {required bool Function() isActive}) async {
    final body = await device.consumeShare(userId);
    if (body == null || body.trim().isEmpty || !isActive()) return null;
    final now = clock();
    final id =
        'shared_${sha256.convert(utf8.encode('$userId|$body|${now.microsecondsSinceEpoch}'))}';
    final parsed = parser.parse(
      id: id,
      sender: 'SHAREDRCS',
      body: body,
      receivedAt: clock(),
    );
    if (parsed == null) return false;
    final data = parsed.toMap();
    data['source'] = 'shared';
    data['reviewReasons'] = [
      ...parsed.reviewReasons,
      'Shared from another app. Verify the sender and payment details before recording.',
    ];
    await device.putReview(userId, data);
    return true;
  }
}
