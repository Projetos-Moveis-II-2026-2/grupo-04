import '../entities/app_user.dart';

abstract interface class IAuthRepository {
  Future<AppUser> signUp({
    required String email,
    required String password,
  });

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> resendConfirmationEmail(String email);

  /// Solicita envio do email de recuperação de senha.
  Future<void> sendPasswordResetEmail(String email);

  /// Atualiza a senha do usuário autenticado via token de recovery.
  Future<void> updatePassword(String newPassword);

  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;
}
