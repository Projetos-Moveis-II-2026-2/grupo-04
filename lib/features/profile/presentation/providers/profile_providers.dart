import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/core/errors/app_exception.dart';
import 'package:olimpus/core/providers.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_providers.dart';
import 'package:olimpus/features/water/presentation/providers/water_providers.dart';

import '../../data/datasources/supabase_profile_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/save_profile.dart';

// ── Datasource ──
final profileDatasourceProvider = Provider<SupabaseProfileDatasource>((ref) {
  return SupabaseProfileDatasource(ref.watch(supabaseClientProvider));
});

// ── Repository ──
final profileRepositoryProvider = Provider<IProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    datasource: ref.watch(profileDatasourceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

// ── UseCases ──
final getProfileUseCaseProvider = Provider<GetProfile>((ref) {
  return GetProfile(ref.watch(profileRepositoryProvider));
});

final saveProfileUseCaseProvider = Provider<SaveProfile>((ref) {
  return SaveProfile(ref.watch(profileRepositoryProvider));
});

// ── Perfil do Usuário Autenticado ──
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(getProfileUseCaseProvider).call(user.id);
});

// ── Status de Conclusão do Onboarding ──
final onboardingStatusProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final repo = ref.watch(profileRepositoryProvider);

  // 1. Se a flag local já estiver marcada, onboarding concluído
  if (repo.isOnboardingCompletedLocally(user.id)) {
    return true;
  }

  // 2. Caso contrário (ex.: troca de dispositivo), consulta perfil remoto
  try {
    final remoteProfile = await ref
        .watch(getProfileUseCaseProvider)
        .call(user.id);
    if (remoteProfile != null && remoteProfile.isCompleted) {
      await repo.setOnboardingCompletedLocally(user.id, completed: true);
      return true;
    }
  } catch (_) {
    // Falhas de rede mantêm o status pendente para não pular indevidamente
    return false;
  }

  return false;
});

// ── Notifier de Submissão do Onboarding ──
class OnboardingNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> completeOnboarding({
    required String displayName,
    required double bodyWeightKg,
    required int dailyWaterGoalMl,
    required ExperienceLevel experienceLevel,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const GenericException('Usuário não autenticado.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();

    try {
      final profile = UserProfile(
        id: user.id,
        displayName: displayName.trim(),
        bodyWeightKg: bodyWeightKg,
        dailyWaterGoalMl: dailyWaterGoalMl,
        experienceLevel: experienceLevel,
      );

      // 1. Salva os dados no profiles do Supabase
      await ref.read(saveProfileUseCaseProvider).call(profile);

      // 2. Persiste a meta de água no SharedPreferences e sincroniza
      await ref.read(dailyWaterGoalProvider.notifier).setGoal(dailyWaterGoalMl);

      // 3. Marca a flag local de conclusão no SharedPreferences
      await ref
          .read(profileRepositoryProvider)
          .setOnboardingCompletedLocally(user.id, completed: true);

      // 4. Invalida os providers para atualizar o estado global
      ref.invalidate(userProfileProvider);
      ref.invalidate(onboardingStatusProvider);

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      final appException = AppException.from(e, st);
      state = AsyncError(appException, st);
      return false;
    }
  }
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, AsyncValue<void>>(
      OnboardingNotifier.new,
    );
