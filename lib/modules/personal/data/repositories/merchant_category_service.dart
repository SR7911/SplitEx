import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_ex/modules/personal/data/mappers/sms/merchant_category_rule_mapper.dart';
import 'package:split_ex/modules/personal/domain/entities/sms/merchant_category_rule.dart';
import 'package:split_ex/modules/personal/domain/policies/sms/bank_sms_parser.dart';
import 'package:split_ex/modules/personal/domain/repositories/merchant_category_repository.dart';

export 'package:split_ex/modules/personal/domain/entities/sms/merchant_category_rule.dart';

class MerchantCategoryService implements MerchantCategoryRepository {
  final FirebaseFirestore db;
  MerchantCategoryService({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> rules(String uid) =>
      db.collection('users').doc(uid).collection('merchant_category_rules');
  Stream<List<MerchantCategoryRule>> watch(String uid) =>
      rules(uid).snapshots().map(
        (s) =>
            s.docs.map((d) => merchantCategoryRuleFromMap(d.data())).toList()
              ..sort((a, b) => a.merchant.compareTo(b.merchant)),
      );
  DocumentReference<Map<String, dynamic>>? ruleFor(
    String uid,
    ParsedBankSms sms,
  ) => sms.direction != BankSmsDirection.debit || sms.merchant == null
      ? null
      : rules(uid).doc(MerchantCategoryRule.key(sms.sender, sms.merchant!));
  Future<String?> suggestion(String uid, ParsedBankSms sms) async {
    final doc = ruleFor(uid, sms);
    if (doc == null) return null;
    final data = (await doc.get()).data();
    return data == null || data['enabled'] == false
        ? null
        : data['category'] as String?;
  }

  Future<void> save(String uid, MerchantCategoryRule rule) async {
    if (!RegExp(
          r'^[A-Z][A-Z0-9-]{1,24}$',
        ).hasMatch(BankSmsParser.normalizeSender(rule.sender)) ||
        rule.merchant.trim().length < 2 ||
        rule.merchant.length > 100 ||
        rule.category.trim().isEmpty)
      throw StateError('Enter a bank sender, merchant and category.');
    await rules(uid).doc(rule.id).set(rule.toMap());
  }

  Future<void> remove(String uid, MerchantCategoryRule rule) =>
      rules(uid).doc(rule.id).delete();
}

