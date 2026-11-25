import '../entities/app_user.dart';

abstract interface class IAuthRepository {
  Future<AppUser> signUp({required String email, required String password});

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> resendConfirmationEmail(String email);

  /// Solicita envio do email de recuperação de senha.
  Future<void> sendPasswordResetEmail(String email);

  /// Atualiza a senha do usuário autenticado via token de recovery.
  Future<void> updatePassword(String newPassword);

  /// Exclui definitivamente a conta do usuário autenticado e todos os dados.
  Future<void> deleteAccount();

  /// Usuário autenticado a cada mudança de sessão (restauração no boot,
  /// login, renovação do token, atualização de dados, logout). Emite só
  /// quando o usuário muda; falhas de rede na renovação não deslogam.
  Stream<AppUser?> authStateChanges();

  /// Emite quando a sessão termina sem ação do usuário: refresh token
  /// expirado/revogado no servidor ou sessão salva inválida.
  Stream<void> sessionExpired();

  AppUser? get currentUser;
}
