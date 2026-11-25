import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/providers/database_providers.dart';
import '../../domain/entities/app_user.dart';
import 'auth_providers.dart';

class AuthNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
    final repo = ref.watch(authRepositoryProvider);
    final current = repo.currentUser;
    return AsyncData(current);
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(signUpUseCaseProvider)
          .call(email: email, password: password),
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () =>
          ref.read(logInUseCaseProvider).call(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await AsyncValue.guard(() => ref.read(logOutUseCaseProvider).call());
    state = const AsyncData(null);
  }

  Future<void> resendConfirmation(String email) async {
    await ref.read(resendConfirmationUseCaseProvider).call(email);
  }

  Future<void> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(resetPasswordUseCaseProvider).call(email);
      return state.value; // Mantém user atual (ou null)
    });
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(updatePasswordUseCaseProvider).call(newPassword);
      await ref
          .read(logOutUseCaseProvider)
          .call(); // Força o logout real no backend
      return null; // Força logout lógico no estado
    });
  }

  /// Reautentica, exclui a conta no backend, limpa dados locais e faz logout.
  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // 1. Reautentica para validar a senha
      await ref
          .read(logInUseCaseProvider)
          .call(email: email, password: password);
      // 2. Chama Edge Function para deletar no backend
      await ref.read(deleteAccountUseCaseProvider).call();
      // 3. Limpa banco local (Drift)
      await ref.read(appDatabaseProvider).deleteAllUserData();
      // 4. Limpa SharedPreferences (flag de pull inicial, etc.)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // 5. signOut local (limpa sessão Supabase do dispositivo)
      await ref.read(logOutUseCaseProvider).call();
      return null; // Força estado deslogado
    });
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<AppUser?>>(AuthNotifier.new);
