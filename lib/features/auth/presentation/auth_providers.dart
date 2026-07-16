import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Streams Supabase auth state so the router can react to sign in/out.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Convenience: the current user (rebuilds on auth change).
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

/// Whether the signed-in user has a verified email (or is a Google user).
final isEmailVerifiedProvider = Provider<bool>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).isEmailVerified;
});

/// Handles form-driven auth actions with a loading/error [AsyncValue] state.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _repo.signInWithEmail(email.trim(), password));

  Future<bool> signUp(String email, String password, String name) =>
      _run(() => _repo.signUpWithEmail(email.trim(), password,
          fullName: name.trim()));

  Future<bool> google() => _run(_repo.signInWithGoogle);

  Future<bool> forgotPassword(String email) =>
      _run(() => _repo.sendPasswordReset(email.trim()));

  Future<bool> resetPassword(String newPassword) =>
      _run(() => _repo.updatePassword(newPassword));

  Future<bool> resendVerification(String email) =>
      _run(() => _repo.resendVerification(email.trim()));
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
