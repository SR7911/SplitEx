import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/sms/merchant_category_rule.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';

export 'package:split_ex/modules/personal/dependencies.dart'
    show bankSmsRepositoryProvider, merchantCategoryServiceProvider;

final merchantCategoryRulesProvider =
    StreamProvider.autoDispose<List<MerchantCategoryRule>>((ref) {
      final uid = ref.watch(authStateProvider).valueOrNull?.uid;
      return uid == null
          ? Stream.value([])
          : ref.watch(merchantCategoryServiceProvider).watch(uid);
    });
