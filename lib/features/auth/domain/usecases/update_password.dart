import '../repositories/i_auth_repository.dart';

class UpdatePassword {
  const UpdatePassword(this._repo);
  final IAuthRepository _repo;

  Future<void> call(String newPassword) => _repo.updatePassword(newPassword);
}
