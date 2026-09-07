import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import 'auth_providers.dart';

class AuthNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
    final repo = ref.watch(authRepositoryProvider);
    final current = repo.currentUser;
    return AsyncData(current);
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signUpUseCaseProvider).call(
            email: email,
            password: password,
          ),
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(logInUseCaseProvider).call(
            email: email,
            password: password,
          ),
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
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<AppUser?>>(AuthNotifier.new);
