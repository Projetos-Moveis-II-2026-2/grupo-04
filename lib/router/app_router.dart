import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/pages/confirmation_pending_page.dart';
import '../features/auth/presentation/pages/delete_account_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/settings_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/exercise/presentation/pages/exercise_details_page.dart';
import '../features/exercise/presentation/pages/exercise_library_page.dart';
import '../features/profile/presentation/pages/onboarding_page.dart';
import '../features/profile/presentation/providers/profile_providers.dart';
import '../features/progress/presentation/pages/progress_page.dart';
import '../features/water/presentation/pages/water_history_page.dart';
import '../features/workout/domain/entities/workout_template_entity.dart';
import '../features/workout/presentation/pages/free_workout_page.dart';
import '../features/workout/presentation/pages/template_form_page.dart';
import '../features/workout/presentation/pages/templates_page.dart';
import '../features/workout/presentation/pages/workout_list_page.dart';
import 'scaffold_with_nav_bar.dart';

/// Chave global do navegador para navegação imperativa de notificações.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Rota pendente vinda de toque em notificação antes de concluir login/onboarding.
final pendingNotificationRouteProvider =
    NotifierProvider<PendingNotificationRouteNotifier, String?>(
      PendingNotificationRouteNotifier.new,
    );

class PendingNotificationRouteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRoute(String? route) => state = route;
  void clear() => state = null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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

      final isResetPasswordRoute =
          location.startsWith('/reset-password') ||
          location.startsWith('/auth/reset-password');

      // 2. Usuário não autenticado tentando acessar rota protegida (inclusive /onboarding)
      if (!isLoggedIn) {
        if (location == '/splash') {
          return '/login';
        }
        if (!isAuthRoute) {
          return '/login';
        }
        return null;
      }

      // 3. Usuário autenticado: verificar status do onboarding
      final onboardingState = ref.read(onboardingStatusProvider);

      // Enquanto o status do onboarding estiver sendo verificado, permanece no splash
      if (onboardingState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isOnboardingCompleted = onboardingState.value ?? false;

      // 4. Se o onboarding estiver pendente
      if (!isOnboardingCompleted) {
        // Permite reset de senha se veio por fluxo de recuperação
        if (isResetPasswordRoute) {
          return null;
        }
        // Se ainda não estiver em /onboarding, força redirecionamento
        return location == '/onboarding' ? null : '/onboarding';
      }

      // 5. Se o onboarding estiver concluído
      // Se houver rota pendente de notificação (ex: /water), direciona para ela
      final pendingRoute = ref.read(pendingNotificationRouteProvider);
      if (pendingRoute != null) {
        Future.microtask(() {
          ref.read(pendingNotificationRouteProvider.notifier).clear();
        });
        return pendingRoute;
      }

      // Bloqueia telas de auth e a própria tela de onboarding (nunca mais volta)
      if (location == '/splash' ||
          location == '/onboarding' ||
          (isAuthRoute && !isResetPasswordRoute)) {
        return '/home';
      }

      return null;
    },
    routes: [
      // ── Rota Raiz (redireciona para /home) ──
      GoRoute(path: '/', redirect: (context, state) => '/home'),

      // ── Splash Screen ──
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),

      // ── Rotas de Autenticação (fora do shell de abas) ──
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
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
      GoRoute(path: '/callback', redirect: (context, state) => '/home'),
      GoRoute(path: '/auth/callback', redirect: (context, state) => '/home'),
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

      // ── Onboarding (fora do shell de abas) ──
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
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
                    path: 'free',
                    builder: (context, state) => const FreeWorkoutPage(),
                  ),
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
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplatesPage(),
      ),
      GoRoute(
        path: '/templates/new',
        builder: (context, state) => const TemplateFormPage(),
      ),
      GoRoute(
        path: '/templates/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          final extra = state.extra;
          return TemplateFormPage(
            templateId: id,
            initialTemplate: extra is WorkoutTemplateEntity ? extra : null,
          );
        },
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
    _ref.listen(onboardingStatusProvider, (_, _) {
      notifyListeners();
    });
  }
}
