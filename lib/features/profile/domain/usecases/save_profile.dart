import '../entities/user_profile.dart';
import '../repositories/i_profile_repository.dart';

/// Caso de uso para salvar ou atualizar o perfil de um usuário.
class SaveProfile {
  final IProfileRepository _repository;

  const SaveProfile(this._repository);

  Future<void> call(UserProfile profile) {
    return _repository.saveProfile(profile);
  }
}
