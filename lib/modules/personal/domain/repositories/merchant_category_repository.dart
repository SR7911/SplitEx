import '../entities/sms/merchant_category_rule.dart';

abstract class MerchantCategoryRepository {
  Stream<List<MerchantCategoryRule>> watch(String uid);
  Future<void> save(String uid, MerchantCategoryRule rule);
  Future<void> remove(String uid, MerchantCategoryRule rule);
}
