import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olimpus/features/auth/domain/entities/app_user.dart';
import 'package:olimpus/features/auth/presentation/providers/auth_notifier.dart';

typedef AuthCredentialsCall = ({String email, String password});

/// Fake controlável de [AuthNotifier] para testes de widget sem Supabase.
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier({
    this.initialState = const AsyncData(null),
    this.onSignIn,
    this.onSignUp,
    this.onSendPasswordReset,
    this.onUpdatePassword,
  });

  final AsyncValue<AppUser?> initialState;

  final Future<AppUser?> Function(String email, String password)? onSignIn;
  final Future<AppUser?> Function(String email, String password)? onSignUp;
  final Future<void> Function(String email)? onSendPasswordReset;
  final Future<void> Function(String newPassword)? onUpdatePassword;

  final List<AuthCredentialsCall> signInCalls = [];
  final List<AuthCredentialsCall> signUpCalls = [];
  final List<String> sendPasswordResetCalls = [];
  final List<String> updatePasswordCalls = [];

  @override
  AsyncValue<AppUser?> build() => initialState;

  void setStateValue(AsyncValue<AppUser?> nextState) {
    state = nextState;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add((email: email, password: password));
    if (onSignIn == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => onSignIn!(email, password));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    signUpCalls.add((email: email, password: password));
    if (onSignUp == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => onSignUp!(email, password));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    sendPasswordResetCalls.add(email);
    if (onSendPasswordReset == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await onSendPasswordReset!(email);
      return state.value;
    });
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatePasswordCalls.add(newPassword);
    if (onUpdatePassword == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await onUpdatePassword!(newPassword);
      return null;
    });
  }
}
