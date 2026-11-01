import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';

final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.uid ?? '';
});

final isDeveloperProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final email = authState.valueOrNull?.email ?? '';
  return email == 'sudharsan7911@gmail.com' ||
      email == 'sudharsansr7911@gmail.com' ||
      email == 'developersr7911@gmail.com';
});
