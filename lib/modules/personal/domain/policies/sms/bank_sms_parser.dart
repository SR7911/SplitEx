import 'dart:convert';
import 'package:crypto/crypto.dart';

enum BankSmsDirection { debit, credit }

class ParsedBankSms {
  final String messageId, sender, body;
  final int amountMinor;
  final BankSmsDirection direction;
  final DateTime date;
  final String? reference, accountLast4, merchant;
  final List<String> reviewReasons;
  const ParsedBankSms({
    required this.messageId,
    required this.sender,
    required this.body,
    required this.amountMinor,
    required this.direction,
    required this.date,
    this.reference,
    this.accountLast4,
    this.merchant,
    this.reviewReasons = const [],
  });
  double get amount => amountMinor / 100;
  bool get canAutoRecord =>
      direction == BankSmsDirection.debit && reviewReasons.isEmpty;
  String get transactionId =>
      'sms_${sha256.convert(utf8.encode(reference == null ? messageId : '${direction.name}|$reference|INR|$amountMinor'))}';
  String get title =>
      merchant ??
      (direction == BankSmsDirection.debit ? 'Bank payment' : 'Bank credit');
  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'sender': sender,
    'body': body,
    'amountMinor': amountMinor,
    'direction': direction.name,
    'date': date.millisecondsSinceEpoch,
    'reference': reference,
    'accountLast4': accountLast4,
    'merchant': merchant,
    'reviewReasons': reviewReasons,
  };
  factory ParsedBankSms.fromMap(Map<String, dynamic> data) => ParsedBankSms(
    messageId: data['messageId'] as String,
    sender: data['sender'] as String,
    body: data['body'] as String,
    amountMinor: (data['amountMinor'] as num).toInt(),
    direction: BankSmsDirection.values.byName(data['direction'] as String),
    date: DateTime.fromMillisecondsSinceEpoch((data['date'] as num).toInt()),
    reference: data['reference'] as String?,
    accountLast4: data['accountLast4'] as String?,
    merchant: data['merchant'] as String?,
    reviewReasons: List<String>.from(data['reviewReasons'] ?? []),
  );
}

class BankSmsParser {
  static String normalizeSender(String sender) {
    final parts = sender.trim().toUpperCase().split('-');
    if (parts.length > 1 && parts.first.length == 2) parts.removeAt(0);
    if (parts.length > 1 && parts.last.length == 1) parts.removeLast();
    return parts.join('-');
  }

  ParsedBankSms? parse({
    required String id,
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) {
    // Numeric personal senders and international currencies are not bank imports.
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9-]{2,24}$').hasMatch(sender.trim())) {
      return null;
    }
    final text = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (RegExp(
      r'\b(?:otp|one.time password|verification code|failed|declined|unsuccessful|payment request|collect request|scheduled|will be debited|not debited)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    if (!RegExp(
      r'\b(?:a\s*/?c|account|acct|card|upi|bank)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }
    final debit = RegExp(
      r'\b(?:debited|spent|paid|sent|charged|deducted|withdrawn|purchase(?:d)?)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final credit = RegExp(
      r'\b(?:credited|received)\b',
      caseSensitive: false,
    ).hasMatch(text);
    if (debit == credit) return null;
    final direction = debit ? BankSmsDirection.debit : BankSmsDirection.credit;
    final amounts = <int>[];
    for (final match in RegExp(
      r'(?:INR\.?|Rs\.?|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)(?![\d,])(?!\.\d)',
      caseSensitive: false,
    ).allMatches(text)) {
      final before = text.substring(0, match.start);
      if (RegExp(
        r'(?:bal(?:ance)?|avl(?:\s+bal(?:ance)?)?|available(?:\s+balance)?|credit limit|outstanding)\s*[:.=-]?\s*$',
        caseSensitive: false,
      ).hasMatch(before)) {
        continue;
      }
      final raw = match.group(1)!;
      if (!RegExp(
        r'^(?:\d+|\d{1,3}(?:,\d{3})+|\d{1,2}(?:,\d{2})*,\d{3})(?:\.\d{1,2})?$',
      ).hasMatch(raw)) {
        continue;
      }
      final parts = raw.replaceAll(',', '').split('.');
      final value = int.tryParse(parts.first);
      if (value == null || value > 1000000000) continue;
      final minor =
          value * 100 +
          (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
      if (minor > 0) amounts.add(minor);
    }
    if (amounts.isEmpty) return null;
    String? reference;
    final references = RegExp(
      r'\b(?:UPI\s*(?:ref(?:erence)?\s*(?:no|number)?)?|(?:txn|transaction|ref(?:erence)?|utr|rrn)\s*(?:id|no|number)?)\s*[:#.=/-]*\s*([A-Z0-9]{6,35})\b',
      caseSensitive: false,
    ).allMatches(text);
    for (final match in references) {
      final value = match.group(1)!;
      if (RegExp(r'\d').hasMatch(value)) {
        reference = value.toUpperCase();
        break;
      }
    }
    reference ??= RegExp(
      r'UPI/(?:P2[MP]/)?(\d{9,20})',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    final account = RegExp(
      r'\b(?:a\s*/?c|account|acct|card)(?:\s*(?:no|number|ending(?:\s+in)?))?\.?\s*[:#-]?\s*(?:[x*•]+[\s-]*)?(\d{4,18})\b',
      caseSensitive: false,
    ).firstMatch(text)?.group(1);
    String? merchant = RegExp(
      (debit ? r'\b(?:to|at)' : r'\bfrom') +
          r'\s+([A-Z][A-Z0-9@._ &-]{1,60}?)(?=\s+(?:on|via|ref|upi|rrn|txn|utr|avl|bal)\b|[.;]|$)',
      caseSensitive: false,
    ).firstMatch(text)?.group(1)?.trim();
    if (merchant != null &&
        RegExp(
          r'^(?:your |INR|Rs\b|account|bank|card)',
          caseSensitive: false,
        ).hasMatch(merchant)) {
      merchant = null;
    }
    final reasons = <String>[];
    if (credit) {
      reasons.add(
        'Confirm whether this is income, a refund, or borrowed money.',
      );
    }
    if (amounts.length != 1) {
      reasons.add('The message contains more than one payment amount.');
    }
    if (reference == null) {
      reasons.add('No reliable transaction reference was found.');
    }
    if (account == null) reasons.add('No account or card ending was found.');
    if (merchant == null) {
      reasons.add('Confirm who this payment was made to or received from.');
    }
    if (RegExp(
      r'\b(?:emi|loan|mandate|autopay|refund|reversal|reversed|self|own account|internal transfer|credit card bill|atm|withdrawn|neft|imps|rtgs)\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      reasons.add(
        'This may be a transfer, EMI, refund, or another linked payment.',
      );
    }
    var date = receivedAt;
    final dateMatch = RegExp(
      r'\b(?:on|dt|date)\s*[:=-]?\s*(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (dateMatch != null) {
      var year = int.parse(dateMatch.group(3)!);
      if (year < 100) year += 2000;
      final month = int.parse(dateMatch.group(2)!);
      final day = int.parse(dateMatch.group(1)!);
      final parsed = DateTime(
        year,
        month,
        day,
        receivedAt.hour,
        receivedAt.minute,
      );
      if (parsed.year == year &&
          parsed.month == month &&
          parsed.day == day &&
          parsed.difference(receivedAt).inDays.abs() <= 31) {
        date = parsed;
        if (parsed.difference(receivedAt).inDays.abs() > 1) {
          reasons.add('Confirm the transaction date.');
        }
      } else {
        reasons.add('The transaction date could not be verified.');
      }
    }
    return ParsedBankSms(
      messageId: id,
      sender: normalizeSender(sender),
      body: body,
      amountMinor: amounts.first,
      direction: direction,
      date: date,
      reference: reference,
      accountLast4: account?.substring(account.length - 4),
      merchant: merchant,
      reviewReasons: reasons,
    );
  }
}
