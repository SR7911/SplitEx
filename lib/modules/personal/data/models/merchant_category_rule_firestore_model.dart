import 'package:split_ex/modules/personal/domain/entities/sms/merchant_category_rule.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';

extension MerchantCategoryRuleFirestore on MerchantCategoryRule {
  Map<String, dynamic> toMap() => {
    'sender': BankSmsParser.normalizeSender(sender),
    'merchant': MerchantCategoryRule.normalizeMerchant(merchant),
    'category': category.trim(),
    'enabled': enabled,
  };
}

MerchantCategoryRule merchantCategoryRuleFromMap(Map<String, dynamic> map) =>
    MerchantCategoryRule(
      sender: map['sender'] as String,
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      enabled: map['enabled'] != false,
    );
