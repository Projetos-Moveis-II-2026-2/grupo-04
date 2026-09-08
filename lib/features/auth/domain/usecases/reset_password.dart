import '../repositories/i_auth_repository.dart';

class ResetPassword {
  const ResetPassword(this._repo);
  final IAuthRepository _repo;

  Future<void> call(String email) => _repo.sendPasswordResetEmail(email);
}
