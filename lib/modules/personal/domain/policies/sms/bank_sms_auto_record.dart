import 'bank_sms_parser.dart';

bool shouldAutoRecordBankSms(
  ParsedBankSms sms, {
  required bool automatic,
  required Set<String> trusted,
  required bool hasPossibleMatch,
}) =>
    automatic &&
    sms.canAutoRecord &&
    trusted.contains(sms.sender) &&
    !hasPossibleMatch;
