import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/datasources/supabase_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/usecases/log_in.dart';
import '../../domain/usecases/log_out.dart';
import '../../domain/usecases/resend_confirmation.dart';
import '../../domain/usecases/sign_up.dart';

// ── Datasource ──
final authDatasourceProvider = Provider<SupabaseAuthDatasource>((ref) {
  return SupabaseAuthDatasource(ref.watch(supabaseClientProvider));
});

// ── Repository ──
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authDatasourceProvider));
});

// ── UseCases ──
final signUpUseCaseProvider = Provider<SignUp>((ref) {
  return SignUp(ref.watch(authRepositoryProvider));
});

final logInUseCaseProvider = Provider<LogIn>((ref) {
  return LogIn(ref.watch(authRepositoryProvider));
});

final logOutUseCaseProvider = Provider<LogOut>((ref) {
  return LogOut(ref.watch(authRepositoryProvider));
});

final resendConfirmationUseCaseProvider = Provider<ResendConfirmation>((ref) {
  return ResendConfirmation(ref.watch(authRepositoryProvider));
});

// ── Auth State Stream ──
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

// ── Current User (sync) ──
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});
