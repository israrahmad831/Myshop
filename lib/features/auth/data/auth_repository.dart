import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/core_providers.dart';

/// Wraps all Supabase auth operations. Screens talk to this, never to Supabase
/// directly, so the auth backend stays swappable.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  bool get isEmailVerified {
    final u = currentUser;
    if (u == null) return false;
    // Google users are pre-verified; email users must confirm.
    return u.emailConfirmedAt != null || u.appMetadata['provider'] == 'google';
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {if (fullName != null) 'full_name': fullName},
      emailRedirectTo: Env.authRedirectUrl,
    );
  }

  /// Native Google sign-in exchanged for a Supabase session via id token.
  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId:
          Env.googleWebClientId.isEmpty ? null : Env.googleWebClientId,
    );
    final account = await google.signIn();
    if (account == null) return; // user cancelled
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthException('Missing Google ID token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth
        .resetPasswordForEmail(email, redirectTo: Env.authRedirectUrl);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Re-sends the confirmation email for an unverified account.
  Future<void> resendVerification(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});
