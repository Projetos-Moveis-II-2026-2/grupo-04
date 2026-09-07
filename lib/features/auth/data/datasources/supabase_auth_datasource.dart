import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDatasource {
  const SupabaseAuthDatasource(this._client);
  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'olimpus://auth/callback',
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resendSignUpConfirmation(String email) {
    return _auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: 'olimpus://auth/callback',
    );
  }

  Stream<AuthState> onAuthStateChange() => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;
  Session? get currentSession => _auth.currentSession;
}
