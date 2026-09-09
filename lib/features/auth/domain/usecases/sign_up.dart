import '../entities/app_user.dart';
import '../repositories/i_auth_repository.dart';

class SignUp {
  const SignUp(this._repo);
  final IAuthRepository _repo;

  Future<AppUser> call({
    required String email,
    required String password,
  }) =>
      _repo.signUp(email: email, password: password);
}
