import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/services/bank_sms_parser.dart';

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
  Map<String, dynamic> toMap() => {
    'sender': BankSmsParser.normalizeSender(sender),
    'merchant': normalizeMerchant(merchant),
    'category': category.trim(),
    'enabled': enabled,
  };
  factory MerchantCategoryRule.fromMap(Map<String, dynamic> map) =>
      MerchantCategoryRule(
        sender: map['sender'] as String,
        merchant: map['merchant'] as String,
        category: map['category'] as String,
        enabled: map['enabled'] != false,
      );
}

class MerchantCategoryService {
  final FirebaseFirestore db;
  MerchantCategoryService({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> rules(String uid) =>
      db.collection('users').doc(uid).collection('merchant_category_rules');
  Stream<List<MerchantCategoryRule>> watch(String uid) =>
      rules(uid).snapshots().map(
        (s) =>
            s.docs.map((d) => MerchantCategoryRule.fromMap(d.data())).toList()
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

final merchantCategoryServiceProvider = Provider(
  (ref) => MerchantCategoryService(),
);
final merchantCategoryRulesProvider =
    StreamProvider.autoDispose<List<MerchantCategoryRule>>((ref) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      return uid == null
          ? Stream.value([])
          : ref.watch(merchantCategoryServiceProvider).watch(uid);
    });
