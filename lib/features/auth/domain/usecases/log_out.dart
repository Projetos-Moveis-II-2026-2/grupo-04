import '../repositories/i_auth_repository.dart';

class LogOut {
  const LogOut(this._repo);
  final IAuthRepository _repo;

  Future<void> call() => _repo.signOut();
}
