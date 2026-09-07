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

  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;
}
