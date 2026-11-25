import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/supabase_auth_datasource.dart';

class AuthRepositoryImpl implements IAuthRepository {
  const AuthRepositoryImpl(this._datasource);
  final SupabaseAuthDatasource _datasource;

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _datasource.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw const AuthException('Signup failed: no user returned');
    }
    return _mapUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _datasource.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Login failed: no user returned');
    }
    return _mapUser(user);
  }

  @override
  Future<void> signOut() => _datasource.signOut();

  @override
  Future<void> resendConfirmationEmail(String email) {
    return _datasource.resendSignUpConfirmation(email);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _datasource.resetPasswordForEmail(email);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final response = await _datasource.updateUser(password: newPassword);
    if (response.user == null) {
      throw const AuthException('Failed to update password');
    }
  }

  @override
  Future<void> deleteAccount() => _datasource.deleteAccount();

  @override
  Stream<AppUser?> authStateChanges() {
    return _datasource.onAuthStateChange().map(
      (event) =>
          event.session?.user != null ? _mapUser(event.session!.user) : null,
    );
  }

  @override
  AppUser? get currentUser {
    final user = _datasource.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  AppUser _mapUser(User user) {
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      emailConfirmedAt: user.emailConfirmedAt != null
          ? DateTime.parse(user.emailConfirmedAt!)
          : null,
    );
  }
}
