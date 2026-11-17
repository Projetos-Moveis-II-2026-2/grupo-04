import '../entities/user_profile.dart';

/// Contrato para o repositório de perfis de usuário.
abstract interface class IProfileRepository {
  /// Obtém o perfil de um usuário pelo seu ID remoto.
  Future<UserProfile?> getProfile(String userId);

  /// Salva ou atualiza os dados do perfil remoto.
  Future<void> saveProfile(UserProfile profile);

  /// Verifica se a flag de onboarding concluído está marcada localmente.
  bool isOnboardingCompletedLocally(String userId);

  /// Grava a flag local de onboarding concluído para o usuário.
  Future<void> setOnboardingCompletedLocally(
    String userId, {
    bool completed = true,
  });
}
