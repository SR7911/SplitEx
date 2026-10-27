import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';

class MerchantCategoryRule {
  final String sender, merchant, category;
  final bool enabled;
  const MerchantCategoryRule({
    required this.sender,
    required this.merchant,
    required this.category,
    this.enabled = true,
  });

  static String normalizeMerchant(String merchant) =>
      merchant.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  static String key(String sender, String merchant) => sha256
      .convert(
        utf8.encode(
          '${BankSmsParser.normalizeSender(sender)}|${normalizeMerchant(merchant)}',
        ),
      )
      .toString();

  String get id => key(sender, merchant);
}
