import '../repositories/i_auth_repository.dart';

class DeleteAccount {
  const DeleteAccount(this._repo);
  final IAuthRepository _repo;

  Future<void> call() => _repo.deleteAccount();
}
