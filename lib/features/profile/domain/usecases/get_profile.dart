import '../entities/user_profile.dart';
import '../repositories/i_profile_repository.dart';

/// Caso de uso para obter o perfil de um usuário.
class GetProfile {
  final IProfileRepository _repository;

  const GetProfile(this._repository);

  Future<UserProfile?> call(String userId) {
    return _repository.getProfile(userId);
  }
}
