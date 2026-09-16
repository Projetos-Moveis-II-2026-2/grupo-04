import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/confirmation_pending_page.dart';
import '../features/auth/presentation/pages/delete_account_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/settings_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/exercise/presentation/pages/exercise_details_page.dart';
import '../features/exercise/presentation/pages/exercise_library_page.dart';
import '../features/progress/presentation/pages/progress_page.dart';
import '../features/water/presentation/pages/water_history_page.dart';
import '../features/workout/presentation/pages/workout_list_page.dart';
import 'scaffold_with_nav_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final location = state.matchedLocation;

      // 1. Enquanto o estado de autenticação estiver carregando, permanece no splash
      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final user = authState.value;
      final isLoggedIn = user != null && user.isEmailConfirmed;

      final isAuthRoute =
          location.startsWith('/login') ||
          location.startsWith('/register') ||
          location.startsWith('/confirmation') ||
          location.startsWith('/callback') ||
          location.startsWith('/auth/callback') ||
          location.startsWith('/forgot-password') ||
          location.startsWith('/reset-password') ||
          location.startsWith('/auth/reset-password');

      // 2. Se estiver na tela de splash e o auth já foi resolvido
      if (location == '/splash') {
        return isLoggedIn ? '/home' : '/login';
      }

      // 3. Usuário não autenticado tentando acessar rota protegida
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // 4. Usuário autenticado tentando acessar tela pública/auth (exceto reset de senha)
      if (isLoggedIn &&
          isAuthRoute &&
          !location.startsWith('/reset-password') &&
          !location.startsWith('/auth/reset-password')) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ── Rota Raiz (redireciona para /home) ──
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),

      // ── Splash Screen ──
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // ── Rotas de Autenticação (fora do shell de abas) ──
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/confirmation',
        builder: (context, state) => ConfirmationPendingPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/callback',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/auth/callback',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),

      // ── Shell com Bottom Navigation Bar (4 abas com estado preservado) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Aba 0 — Início (Dashboard)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),

          // Aba 1 — Treinos
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const WorkoutListPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return Scaffold(
                        appBar: AppBar(title: Text('Treino $id')),
                        body: Center(
                          child: Text('Detalhes da ficha de treino $id'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Aba 2 — Exercícios
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (context, state) => const ExerciseLibraryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return ExerciseDetailsPage.fromRouteState(
                        id: id,
                        extra: state.extra,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Aba 3 — Progresso
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressPage(),
              ),
            ],
          ),
        ],
      ),

      // ── Rotas Internas Globais (fora do shell, abrem sem barra inferior) ──
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/delete-account',
        builder: (context, state) => const DeleteAccountPage(),
      ),
      GoRoute(
        path: '/water',
        builder: (context, state) => const WaterHistoryPage(),
      ),
    ],
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) {
      notifyListeners();
    });
  }
}
