import '../../policies/sms/bank_sms_auto_record.dart';
import '../../policies/sms/bank_sms_parser.dart';
import '../../repositories/bank_sms_device_gateway.dart';
import '../../repositories/bank_sms_repository.dart';

/// Imports queued device alerts while keeping acknowledgement after each item.
class ProcessBankSmsQueue {
  final PersonalBankSmsRepository repository;
  final BankSmsDeviceGateway device;
  final BankSmsParser parser;

  ProcessBankSmsQueue(this.repository, this.device, {BankSmsParser? parser})
    : parser = parser ?? BankSmsParser();

  Future<void> call({
    required String userId,
    required bool Function() isActive,
    required bool Function() automatic,
    required Set<String> Function() trustedSenders,
  }) async {
    final queue = await device.queue(userId);
    for (final item in queue) {
      if (!isActive()) break;
      if (item['owner'] != userId) continue;
      final id = item['id'] as String;
      final sms = parser.parse(
        id: id,
        sender: item['sender'] as String,
        body: item['body'] as String,
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          (item['timestamp'] as num).toInt(),
        ),
      );
      if (sms != null && !await repository.wasRecorded(userId, sms)) {
        final matches = await repository.possibleMatches(userId, sms);
        if (!isActive()) break;
        final trusted = trustedSenders();
        if (item['source'] != 'rcs' &&
            shouldAutoRecordBankSms(
              sms,
              automatic: automatic(),
              trusted: trusted,
              hasPossibleMatch: matches.isNotEmpty,
            )) {
          await repository.save(
            userId,
            sms,
            matchAccount: true,
            applyMerchantRule: true,
          );
        } else {
          final data = sms.toMap();
          data['source'] = item['source'] == 'rcs' ? 'rcs' : 'sms';
          final reasons = [...sms.reviewReasons];
          if (!trusted.contains(sms.sender)) {
            reasons.add(
              'Verify this sender before enabling automatic recording for it.',
            );
          }
          if (matches.isNotEmpty) {
            reasons.add(
              'A similar transaction already exists. Check for an EMI, settlement, or manual entry.',
            );
          }
          if (item['source'] == 'rcs') {
            reasons.add(
              'Captured from a Google Messages notification. Verify the sender and payment details before recording.',
            );
          }
          data['reviewReasons'] = reasons;
          await device.putReview(userId, data);
        }
      }
      await device.acknowledge(userId, id);
    }
  }
}
