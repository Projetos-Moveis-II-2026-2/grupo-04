import '../repositories/i_auth_repository.dart';

class ResendConfirmation {
  const ResendConfirmation(this._repo);
  final IAuthRepository _repo;

  Future<void> call(String email) => _repo.resendConfirmationEmail(email);
}
