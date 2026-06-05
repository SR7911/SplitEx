import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/models/user_model.dart';
import 'package:split_ex/services/auth_service.dart';
import 'package:split_ex/services/user_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userServiceProvider = Provider<UserService>((ref) => UserService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).userStream(user.uid);
});

final profileExistsProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return false;
  return ref.watch(userServiceProvider).profileExists(user.uid);
});
